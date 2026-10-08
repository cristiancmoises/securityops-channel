"""Exercise native Wazuh in a disposable, network-isolated QEMU guest only.

The guest must contain a dedicated wazuh account/group, immutable package
closures, and mount/core tools.  Never invoke this on the operator's host.
"""

import argparse
import base64
import grp
import json
import os
import pwd
import secrets
import select
import shutil
import signal
import ssl
import stat
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from contextlib import contextmanager
from pathlib import Path


def guest_guard():
    assert os.environ.get("SECURITYOPS_WAZUH_DISPOSABLE_GUEST") == "1"
    assert os.geteuid() == 0, "upstream privilege separation requires guest root"
    product = Path("/sys/class/dmi/id/product_name").read_text().strip()
    assert product.startswith(("Standard PC", "QEMU")), product
    assert {entry.name for entry in Path("/sys/class/net").iterdir()} == {"lo"}
    account = pwd.getpwnam("wazuh")
    group = grp.getgrnam("wazuh")
    assert account.pw_uid != 0 and group.gr_gid != 0
    return account.pw_uid, group.gr_gid


def command(package, name, state, *arguments, input_text=None, cwd=None):
    return subprocess.run(
        [str(package / "bin" / name), *arguments],
        env={**os.environ, "WAZUH_HOME": str(state)},
        cwd=cwd,
        input=input_text,
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )


def provision(package, state, uid, gid):
    state.mkdir(mode=0o750)
    os.chown(state, 0, gid)
    for name in ("etc", "ruleset"):
        shutil.copytree(package / "share/wazuh" / name, state / name)
    for name in ("api", "queue", "var", "templates"):
        assets = package / "share/wazuh" / name
        if assets.exists():
            shutil.copytree(assets, state / name)
    for name in (
        "logs/alerts",
        "logs/archives",
        "logs/firewall",
        "logs/api",
        "queue/sockets",
        "queue/alerts",
        "queue/rids",
        "queue/fts",
        "queue/db",
        "queue/tasks",
        "queue/agent-info",
        "queue/agent-groups",
        "queue/syscollector/db",
        "queue/fim/db",
        "queue/logcollector",
        "queue/diff",
        "queue/keystore",
        "var/run",
        "var/run/active-response",
        "var/active-response",
        "var/wodles/aws",
        "var/wodles/azure",
        "var/wodles/gcloud",
        "var/db",
        "var/incoming",
        "var/upgrade",
        "stats",
        "tmp",
        "etc/shared",
        "etc/rules",
        "etc/decoders",
        "etc/lists",
        "backup/db",
        "agentless",
        "gnu/store",
    ):
        directory = state / name
        directory.mkdir(parents=True, exist_ok=True)
    if (package / "bin/wazuh-db").exists():
        # The upstream installer provisions the manager's default shared group.
        # Copy original data only; no test configuration is sent to the host.
        default_group = state / "etc/shared/default"
        default_group.mkdir()
        shutil.copyfile(state / "etc/agent.conf", default_group / "agent.conf")
        for database in (state / "ruleset/rootcheck/db").glob("*.txt"):
            shutil.copyfile(database, default_group / database.name)
    (state / "bin").symlink_to(package / "bin", target_is_directory=True)
    (state / "lib").symlink_to(package / "lib", target_is_directory=True)
    for name in ("wodles", "integrations"):
        assets = package / "libexec/wazuh" / name
        if assets.exists():
            (state / name).symlink_to(assets, target_is_directory=True)
    (state / "active-response").mkdir()
    (state / "active-response/bin").symlink_to(
        package / "libexec/wazuh/active-response/bin", target_is_directory=True
    )
    immutable_agentless = package / "libexec/wazuh/agentless"
    if immutable_agentless.exists():
        for script in immutable_agentless.iterdir():
            (state / "agentless" / script.name).symlink_to(script)
    for directory, _, files in os.walk(state):
        os.chown(directory, uid, gid)
        os.chmod(directory, 0o750)
        for name in files:
            file = Path(directory) / name
            if not file.is_symlink():
                os.chown(file, uid, gid)
                os.chmod(file, 0o640)
    os.chown(state, 0, gid)
    # This parent contains executable aliases, not writable lock/state data.
    response_code = state / "active-response"
    os.chown(response_code, 0, gid)
    response_code.chmod(0o750)
    assert response_code.stat().st_uid == 0
    assert response_code.stat().st_mode & 0o022 == 0
    assert (response_code / "bin").resolve() == (
        package / "libexec/wazuh/active-response/bin"
    ).resolve()


@contextmanager
def temporary_state():
    parent = Path(tempfile.mkdtemp(prefix="securityops-wazuh-core-"))
    try:
        yield parent
    finally:
        mountpoints = {
            Path(line.split()[4])
            for line in Path("/proc/self/mountinfo").read_text().splitlines()
        }
        if any(parent == mount or parent in mount.parents for mount in mountpoints):
            # Do not recursively clean through a failed/untracked bind mount.
            print(f"Preserved fixture state containing an active mount: {parent}")
        else:
            assert parent.name.startswith("securityops-wazuh-core-")
            shutil.rmtree(parent)


def stop(process):
    try:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=10)
    finally:
        if isinstance(process, ForkedDaemon):
            process.close()


class ForkedDaemon:
    """Monitor only a verified owned child, without signaling a reused PID."""

    def __init__(self, pid, descriptor):
        self.pid = pid
        self.descriptor = descriptor

    def poll(self):
        # A pidfd becomes readable on termination, including an orphan reaped
        # by guest PID1.  Its exit status is not available to this non-parent.
        return 1 if select.select([self.descriptor], [], [], 0)[0] else None

    def terminate(self):
        try:
            signal.pidfd_send_signal(self.descriptor, signal.SIGTERM)
        except ProcessLookupError:
            pass  # The pinned process terminated before the signal.

    def kill(self):
        try:
            signal.pidfd_send_signal(self.descriptor, signal.SIGKILL)
        except ProcessLookupError:
            pass

    def wait(self, timeout):
        if not select.select([self.descriptor], [], [], timeout)[0]:
            raise subprocess.TimeoutExpired(str(self.pid), timeout)
        return 1

    def close(self):
        os.close(self.descriptor)


def follow_forked_daemon(launcher, state, name, executable, root, uid):
    """Follow upstream remoted's per-connection fork even with its -f flag."""
    assert launcher.wait(timeout=10) == 0, "daemon launcher failed"
    deadline = time.monotonic() + 10
    while True:
        files = list((state / "var/run").glob(f"{name}-*.pid"))
        assert len(files) <= 1, "unexpected extra connection process"
        if files:
            break
        assert time.monotonic() < deadline, "forked daemon never wrote its PID"
        time.sleep(0.05)
    pidfile = files[0]
    descriptor = os.open(pidfile, os.O_RDONLY | os.O_NOFOLLOW)
    with os.fdopen(descriptor, "r") as stream:
        metadata = os.fstat(stream.fileno())
        assert stat.S_ISREG(metadata.st_mode)
        assert metadata.st_uid == uid and metadata.st_mode & 0o777 == 0o640
        value = stream.read().strip()
    assert value.isascii() and value.isdecimal(), "invalid owned PID record"
    pid = int(value)
    assert pid > 1 and pidfile.name == f"{name}-{pid}.pid"
    descriptor = os.pidfd_open(pid)
    try:
        assert os.getpgid(pid) == launcher.pid, "not the owned isolated session"
        process = Path(f"/proc/{pid}")
        status = (process / "status").read_text()
        assert f"Uid:\t{uid}\t{uid}\t{uid}\t{uid}" in status
        executable = executable.resolve()
        assert str(executable).startswith("/gnu/store/")
        assert (process / "exe").resolve() == executable
        assert (process / "root").resolve() == root.resolve()
        descriptor_info = Path(f"/proc/self/fdinfo/{descriptor}").read_text()
        assert f"Pid:\t{pid}\n" in descriptor_info
        owned = ForkedDaemon(pid, descriptor)
        assert owned.poll() is None, "verified daemon already terminated"
    except BaseException:
        os.close(descriptor)
        raise
    return owned


def prepare_api(package, manager, uid, gid):
    configuration = manager / "api/configuration"
    security = configuration / "security"
    security.mkdir(parents=True, exist_ok=True)
    os.chown(security, uid, gid)
    security.chmod(0o700)
    tls = configuration / "ssl"
    tls.mkdir(mode=0o700, exist_ok=True)
    subprocess.run(
        [
            str(package / "libexec/wazuh/python/bin/python3"),
            "-I",
            "-B",
            "-c",
            (
                "from pathlib import Path; import sys, ipaddress; "
                "from datetime import datetime, timedelta, timezone; "
                "from cryptography import x509; "
                "from cryptography.hazmat.primitives import hashes, serialization; "
                "from cryptography.hazmat.primitives.asymmetric import rsa; "
                "from cryptography.x509.oid import NameOID; "
                "p=Path(sys.argv[1]); k=rsa.generate_private_key(public_exponent=65537,key_size=2048); "
                "n=x509.Name([x509.NameAttribute(NameOID.COMMON_NAME,'local fixture')]); "
                "now=datetime.now(timezone.utc); "
                "c=x509.CertificateBuilder().subject_name(n).issuer_name(n).public_key(k.public_key())"
                ".serial_number(x509.random_serial_number()).not_valid_before(now-timedelta(minutes=1))"
                ".not_valid_after(now+timedelta(days=1))"
                ".add_extension(x509.BasicConstraints(ca=True,path_length=None),critical=True)"
                ".add_extension(x509.SubjectAlternativeName([x509.IPAddress(ipaddress.ip_address('127.0.0.1'))]),critical=False)"
                ".sign(k,hashes.SHA256()); "
                "(p/'server.key').write_bytes(k.private_bytes(serialization.Encoding.PEM,serialization.PrivateFormat.PKCS8,serialization.NoEncryption())); "
                "(p/'server.key').chmod(0o600); "
                "(p/'server.crt').write_bytes(c.public_bytes(serialization.Encoding.PEM))"
            ),
            str(tls),
        ],
        check=True,
        timeout=30,
    )
    # The upstream API drops privileges before serving TLS.  Private keys and
    # their parent directory must remain accessible to that dedicated account.
    for asset in (tls, tls / "server.key", tls / "server.crt"):
        os.chown(asset, uid, gid)
    assert tls.stat().st_mode & 0o777 == 0o700
    assert (tls / "server.key").stat().st_mode & 0o777 == 0o600
    (configuration / "api.yaml").write_text(
        json.dumps(
            {
                "host": ["127.0.0.1"],
                "port": 55000,
                "drop_privileges": True,
                "authentication_pool_size": 1,
                "https": {"enabled": True, "key": "server.key", "cert": "server.crt"},
                "logs": {"level": "info", "format": "plain"},
            }
        )
    )
    password = "Fixture-A1-" + secrets.token_urlsafe(32)
    users = {
        "default_users": {
            "wazuh": {"password": password, "allow_run_as": False},
            "wazuh-wui": {
                "password": "Fixture-W2-" + secrets.token_urlsafe(32),
                "allow_run_as": True,
            },
        }
    }
    return security / "initial-users.yaml", users, password, tls / "server.crt"


def prepare_shared_baseline(package, manager, agent, uid, gid):
    """Use native group initialization and an already-synchronized snapshot."""
    deadline = time.monotonic() + 30
    group = manager / "etc/shared/default"
    merged = group / "merged.mg"
    while True:
        result = subprocess.run(
            [
                str(package / "libexec/wazuh/python/bin/python3"),
                "-I",
                "-B",
                "-c",
                (
                    "import json; from wazuh.core.wdb import WazuhDBConnection; "
                    "connection = WazuhDBConnection(); "
                    "print(json.dumps(connection.send('global find-group default', raw=False))); "
                    "connection.close()"
                ),
            ],
            env={**os.environ, "WAZUH_HOME": str(manager)},
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
        assert result.returncode == 0, (result.stdout, result.stderr)
        rows = json.loads(result.stdout)
        if rows and merged.is_file() and merged.stat().st_size:
            assert len(rows) == 1 and rows[0]["id"] > 0, rows
            break
        assert time.monotonic() < deadline, "Native default group never became ready"
        time.sleep(0.5)
    for original in group.iterdir():
        assert original.is_file() and not original.is_symlink(), original
        destination = agent / "etc/shared" / original.name
        shutil.copyfile(original, destination)
        os.chown(destination, uid, gid)
        destination.chmod(0o640)
        assert destination.read_bytes() == original.read_bytes(), original
    assert (agent / "etc/shared/merged.mg").read_bytes() == merged.read_bytes()
    print("PASS: native default group and byte-identical shared baseline ready")


def api_request(opener, path, authorization=None):
    headers = {} if authorization is None else {"Authorization": authorization}
    request = urllib.request.Request("https://127.0.0.1:55000" + path, headers=headers)
    try:
        with opener.open(request, timeout=5) as response:
            return response.status, response.read()
    except urllib.error.HTTPError as error:
        return error.code, error.read()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--manager", type=Path, required=True)
    parser.add_argument("--agent", type=Path, required=True)
    parser.add_argument("--alert-copy", type=Path)
    parser.add_argument("--integration-fixture", type=Path)
    parser.add_argument("--indexer", type=Path)
    parser.add_argument("--dashboard", type=Path)
    parser.add_argument("--filebeat", type=Path)
    arguments = parser.parse_args()
    integration = (
        arguments.integration_fixture,
        arguments.indexer,
        arguments.dashboard,
        arguments.filebeat,
    )
    if any(integration) and not all(integration):
        parser.error("integration requires fixture, indexer, dashboard and Filebeat")
    uid, gid = guest_guard()
    for package in (arguments.manager, arguments.agent):
        assert str(package.resolve()).startswith("/gnu/store/")
    with temporary_state() as parent:
        parent.chmod(0o755)
        manager = parent / "manager"
        agent = parent / "agent"
        mounted = []
        processes = []
        logs = []
        try:
            for package, state in (
                (arguments.manager, manager),
                (arguments.agent, agent),
            ):
                provision(package, state, uid, gid)
                # Keep immutable executable closures available inside the
                # original chroot, tracking the bind before remounting it.
                subprocess.run(
                    ["mount", "--bind", "/gnu/store", str(state / "gnu/store")],
                    check=True,
                )
                mounted.append(state / "gnu/store")
                subprocess.run(
                    ["mount", "-o", "remount,bind,ro", str(state / "gnu/store")],
                    check=True,
                )
                (state / "etc/client.keys").write_text("")
                os.chown(state / "etc/client.keys", uid, gid)
                (state / "etc/client.keys").chmod(0o640)
            token = "securityops-fixture-" + secrets.token_hex(12)
            # Keys are generated for this local fixture only and never printed.
            key = secrets.token_hex(32)
            for state in (manager, agent):
                (state / "etc/client.keys").write_text(
                    f"001 fixture-agent 127.0.0.1 {key}\n"
                )
            stock_configuration = (
                arguments.manager / "share/wazuh/etc/ossec-server.conf"
            ).read_text()
            (manager / "etc/ossec.conf").write_text(stock_configuration)
            stock = command(arguments.manager, "wazuh-analysisd", manager, "-t")
            assert stock.returncode == 0, (stock.stdout, stock.stderr)
            for relative in (
                "audit-keys",
                "malicious-ioc/malware-hashes",
                "malicious-ioc/malicious-ip",
                "malicious-ioc/malicious-domains",
            ):
                database = manager / "etc/lists" / (relative + ".cdb")
                assert database.is_file() and database.stat().st_size > 0, database
            print("PASS: native stock rule configuration compiles actual CDB lists")
            (manager / "etc/rules/local_rules.xml").write_text(
                '<group name="securityops_fixture,">\n'
                '<rule id="100001" level="5"><decoded_as>json</decoded_as>'
                f'<field name="securityops_fixture">^{token}$</field>'
                "<description>Local synthetic acceptance event</description>"
                "<mitre><id>T1059</id></mitre>"
                "</rule>\n</group>\n"
            )
            (manager / "etc/ossec.conf").write_text(
                "<ossec_config><global><jsonout_output>yes</jsonout_output>"
                "<alerts_log>yes</alerts_log></global>"
                "<alerts><log_alert_level>3</log_alert_level></alerts>"
                "<remote><connection>secure</connection><port>1514</port>"
                "<protocol>tcp</protocol><local_ip>127.0.0.1</local_ip></remote>"
                "<ruleset><decoder_include>ruleset/decoders/0006-json_decoders.xml</decoder_include>"
                "<rule_include>etc/rules/local_rules.xml</rule_include>"
                "<list>etc/lists/audit-keys</list>"
                "<list>etc/lists/amazon/aws-eventnames</list>"
                "<list>etc/lists/malicious-ioc/malware-hashes</list>"
                "<list>etc/lists/malicious-ioc/malicious-ip</list>"
                "<list>etc/lists/malicious-ioc/malicious-domains</list></ruleset>"
                "<active-response><disabled>yes</disabled></active-response>"
                '<wodle name="syscollector"><disabled>yes</disabled></wodle>'
                "<vulnerability-detection><enabled>no</enabled></vulnerability-detection>"
                "<indexer><enabled>no</enabled></indexer>"
                "<sca><enabled>no</enabled></sca><syscheck><disabled>yes</disabled></syscheck>"
                "<rootcheck><disabled>yes</disabled></rootcheck>"
                "</ossec_config>\n"
            )
            event_file = agent / "events.json"
            event_file.write_text("")
            (agent / "etc/ossec.conf").write_text(
                "<ossec_config><client><server><address>127.0.0.1</address>"
                "<port>1514</port><protocol>tcp</protocol></server>"
                "<crypto_method>aes</crypto_method><notify_time>2</notify_time>"
                "<time-reconnect>5</time-reconnect></client>"
                "<localfile><log_format>json</log_format>"
                f"<location>{event_file}</location></localfile>"
                "<active-response><disabled>yes</disabled></active-response>"
                '<wodle name="syscollector"><disabled>no</disabled><interval>1h</interval>'
                "<scan_on_start>yes</scan_on_start><hardware>yes</hardware><os>yes</os>"
                '<network>no</network><packages>no</packages><ports all="no">no</ports>'
                "<processes>no</processes><browser_extensions>no</browser_extensions>"
                "<users>no</users><groups>no</groups><services>no</services>"
                "</wodle>"
                "<sca><enabled>no</enabled></sca><syscheck><disabled>yes</disabled></syscheck>"
                "<rootcheck><disabled>yes</disabled></rootcheck>"
                "</ossec_config>\n"
            )

            # Start with a complete working state: failure caused by a missing
            # configuration is not evidence that an ownership guard worked.
            # Upstream error logging reads etc/ossec.conf from cwd.  Keep the
            # same provisioned cwd for valid and invalid metadata probes.
            def state_probe(state, expected=None):
                probes = [
                    command(arguments.agent, "wazuh-agentd", state, "-V", cwd=agent),
                    command(arguments.agent, "wazuh-control", state, "info", cwd=agent),
                    subprocess.run(
                        [
                            str(arguments.agent / "libexec/wazuh/python/bin/python3"),
                            "-I",
                            "-B",
                            "-c",
                            (
                                "from wazuh.core.common import find_wazuh_path; "
                                "print(find_wazuh_path())"
                            ),
                        ],
                        env={**os.environ, "WAZUH_HOME": str(state)},
                        cwd=agent,
                        capture_output=True,
                        text=True,
                        timeout=30,
                        check=False,
                    ),
                ]
                for index, result in enumerate(probes):
                    evidence = (
                        state,
                        index,
                        result.returncode,
                        result.stdout,
                        result.stderr,
                    )
                    if expected is None:
                        assert result.returncode == 0, evidence
                    else:
                        assert result.returncode != 0, evidence
                        message = expected[1] if index == 2 else expected[0]
                        assert message in result.stdout + result.stderr, evidence

            ownership_error = (
                "Unsafe WAZUH_HOME state ownership or ancestry",
                "WAZUH_HOME ancestry must be safely owned directories",
            )
            permissions_error = (
                ownership_error[0],
                "WAZUH_HOME ancestry must not be group/world-writable",
            )
            state_probe(agent)
            for mode in (0o770, 0o777):
                try:
                    agent.chmod(mode)
                    state_probe(agent, permissions_error)
                finally:
                    agent.chmod(0o750)
            try:
                os.chown(agent, 65534, 65534)
                state_probe(agent, ownership_error)
            finally:
                os.chown(agent, 0, gid)
            # The target remains the same valid state.  Only alias metadata or
            # its lexical parent changes, independently of the canonical path.
            alias_parent = parent / "state-alias"
            alias_parent.mkdir(mode=0o750)
            alias = alias_parent / "state"
            alias.symlink_to(agent, target_is_directory=True)
            state_probe(alias)
            try:
                alias_parent.chmod(0o770)
                state_probe(alias, permissions_error)
            finally:
                alias_parent.chmod(0o750)
            try:
                os.chown(alias, 65534, 65534, follow_symlinks=False)
                state_probe(alias, ownership_error)
            finally:
                os.chown(alias, 0, 0, follow_symlinks=False)
            state_probe(alias)
            for invalid in (Path("/"), Path("/gnu/store")):
                result = command(
                    arguments.agent, "wazuh-agentd", invalid, "-V", cwd=agent
                )
                assert result.returncode != 0, (invalid, result.stdout, result.stderr)
                assert ownership_error[0] in result.stdout + result.stderr
            print("PASS: C, isolated Python and control reject unsafe state metadata")
            # Root execd must refuse a replaceable executable-alias parent
            # without starting a daemon or invoking an active-response action.
            response_code = manager / "active-response"
            result = command(
                arguments.manager, "wazuh-execd", manager, "-V", cwd=manager
            )
            assert result.returncode == 0, (result.stdout, result.stderr)
            for owner, mode in ((0, 0o770), (uid, 0o750)):
                try:
                    os.chown(response_code, owner, gid)
                    response_code.chmod(mode)
                    result = command(
                        arguments.manager, "wazuh-execd", manager, "-V", cwd=manager
                    )
                    assert result.returncode != 0, (result.stdout, result.stderr)
                    assert (
                        "Unsafe active-response executable directory ownership or ancestry"
                        in result.stdout + result.stderr
                    ), (result.stdout, result.stderr)
                finally:
                    os.chown(response_code, 0, gid)
                    response_code.chmod(0o750)
            print("PASS: root execd refuses unsafe executable aliases without actions")
            spaced_alias = alias_parent / "ordinary space"
            spaced_alias.symlink_to(agent, target_is_directory=True)
            result = command(
                arguments.agent, "wazuh-agentd", spaced_alias, "-V", cwd=agent
            )
            assert result.returncode == 0, (result.stdout, result.stderr)
            result = command(
                arguments.agent, "wazuh-control", spaced_alias, "info", cwd=agent
            )
            assert result.returncode != 0, (result.stdout, result.stderr)
            assert "Control requires a supported ASCII state path" in result.stderr
            print(
                "PASS: control rejects unsupported path spelling before shell operations"
            )
            for package, state, role in (
                (arguments.manager, manager, "server"),
                (arguments.agent, agent, "agent"),
            ):
                result = command(package, "wazuh-control", state, "info")
                assert result.returncode == 0, result.stderr
                assert f'WAZUH_TYPE="{role}"' in result.stdout
            print("PASS: immutable control scripts use explicit component state")
            event = json.dumps({"securityops_fixture": token}) + "\n"
            result = command(
                arguments.manager,
                "wazuh-logtest-legacy",
                manager,
                "-U",
                "100001:5:json",
                input_text=event,
            )
            assert result.returncode == 0, (result.stdout, result.stderr)
            # Upstream print_out deliberately writes phase/decoder details to
            # stderr; stdout contains only the successful -U result code.
            assert result.stdout.strip() == "0", (result.stdout, result.stderr)
            assert "Rule id: '100001'" in result.stderr, result.stderr
            assert "Level: '5'" in result.stderr, result.stderr
            assert "lf->decoder_info->name: 'json'" in result.stderr, result.stderr
            mismatch = command(
                arguments.manager,
                "wazuh-logtest-legacy",
                manager,
                "-U",
                "100002:5:json",
                input_text=event,
            )
            assert mismatch.returncode == 2, (
                mismatch.stdout,
                mismatch.stderr,
            )
            assert "Rule id: '100001'" in mismatch.stderr, mismatch.stderr
            assert "lf->decoder_info->name: 'json'" in mismatch.stderr, mismatch.stderr
            print(result.stderr)
            print("PASS: compiled decoder/rule engine evaluates synthetic JSON")
            for package, state, name in (
                (arguments.manager, manager, "wazuh-db"),
                (arguments.manager, manager, "wazuh-analysisd"),
                (arguments.manager, manager, "wazuh-remoted"),
                (arguments.manager, manager, "wazuh-execd"),
                (arguments.manager, manager, "wazuh-modulesd"),
                (arguments.agent, agent, "wazuh-execd"),
                (arguments.agent, agent, "wazuh-agentd"),
                (arguments.agent, agent, "wazuh-logcollector"),
                (arguments.agent, agent, "wazuh-modulesd"),
            ):
                if state == agent and name == "wazuh-execd":
                    prepare_shared_baseline(arguments.manager, manager, agent, uid, gid)
                if state == agent and name == "wazuh-agentd":
                    assert (agent / "queue/sockets/com").is_socket(), (
                        "Endpoint control socket must be ready before the agent connects"
                    )
                log = (parent / f"{state.name}-{name}.log").open("w+")
                logs.append(log)
                process = subprocess.Popen(
                    [str(package / "bin" / name), "-f"],
                    env={**os.environ, "WAZUH_HOME": str(state)},
                    stdout=log,
                    stderr=subprocess.STDOUT,
                    start_new_session=name == "wazuh-remoted",
                )
                processes.append(process)
                time.sleep(1)
                if name == "wazuh-remoted":
                    executable = package / "bin" / name
                    with executable.open("rb") as binary:
                        is_elf = binary.read(4) == b"\x7fELF"
                    if not is_elf:
                        executable = package / "bin" / f".{name}-real"
                    process = follow_forked_daemon(
                        process, state, name, executable, state, uid
                    )
                    processes[-1] = process
                    print("PASS: actual owned remoted child retains UID and chroot")
                assert process.poll() is None, f"{name} exited early"
                if state == agent and name == "wazuh-execd":
                    deadline = time.monotonic() + 10
                    while not (agent / "queue/sockets/com").is_socket():
                        assert process.poll() is None, "Endpoint execd exited early"
                        assert time.monotonic() < deadline, (
                            "Endpoint control socket missing"
                        )
                        time.sleep(0.1)
                    assert not (agent / "queue/alerts/execq").exists()
                    print(
                        "PASS: endpoint control socket ready with active response disabled"
                    )
            initial_users, users, password, certificate = prepare_api(
                arguments.manager, manager, uid, gid
            )
            missing = command(arguments.manager, "wazuh-apid", manager, "-f")
            assert missing.returncode != 0
            assert "initial-users.yaml" in missing.stdout + missing.stderr
            print("PASS: actual API first boot refuses missing private users")
            initial_users.write_text(json.dumps(users))
            os.chown(initial_users, uid, gid)
            initial_users.chmod(0o600)
            imported = subprocess.run(
                [
                    str(arguments.manager / "libexec/wazuh/python/bin/python3"),
                    "-I",
                    "-B",
                    "-c",
                    (
                        "from wazuh.rbac import orm; users = orm.load_initial_users(); "
                        "assert {'wazuh', 'wazuh-wui'}.issubset(users['default_users'])"
                    ),
                ],
                env={**os.environ, "WAZUH_HOME": str(manager)},
                user=uid,
                group=gid,
                extra_groups=[],
                capture_output=True,
                text=True,
                timeout=30,
                check=False,
            )
            assert imported.returncode == 0, imported.stderr
            print(
                "PASS: exact installed RBAC module imports and loads private users without injected globals"
            )
            api_log = (parent / "manager-api.log").open("w+")
            logs.append(api_log)
            api = subprocess.Popen(
                [str(arguments.manager / "bin/wazuh-apid"), "-f"],
                env={**os.environ, "WAZUH_HOME": str(manager)},
                stdout=api_log,
                stderr=subprocess.STDOUT,
            )
            processes.append(api)
            opener = urllib.request.build_opener(
                urllib.request.ProxyHandler({}),
                urllib.request.HTTPSHandler(
                    context=ssl.create_default_context(cafile=str(certificate))
                ),
            )
            deadline = time.monotonic() + 30
            while True:
                assert api.poll() is None, "API exited before accepting local TLS"
                try:
                    status, _ = api_request(opener, "/agents")
                    break
                except urllib.error.URLError:
                    assert time.monotonic() < deadline
                    time.sleep(0.5)
            assert status == 401
            basic = base64.b64encode(f"wazuh:{password}".encode()).decode()
            status, response = api_request(
                opener, "/security/user/authenticate?raw=true", "Basic " + basic
            )
            assert status == 200
            authorization = "Bearer " + response.decode().strip('"\n')
            status, response = api_request(opener, "/", authorization)
            assert status == 200 and "4.14.8" in response.decode()
            status, _ = api_request(opener, "/agents", "Bearer invalid-fixture-token")
            assert status == 401
            print(
                "PASS: verified TLS, private-user login, authenticated API, rejected bad JWT"
            )
            deadline = time.monotonic() + 30
            while True:
                status, response = api_request(
                    opener,
                    "/agents?agents_list=001&select=id,group,group_config_status",
                    authorization,
                )
                assert status == 200, status
                agents = json.loads(response)["data"]["affected_items"]
                if agents and agents[0].get("group_config_status") == "synced":
                    assert len(agents) == 1 and agents[0]["id"] == "001", agents
                    assert "default" in agents[0]["group"], agents
                    break
                assert time.monotonic() < deadline, (
                    "Shared configuration never synchronized"
                )
                time.sleep(0.5)
            print(
                "PASS: authenticated API reports the exact endpoint default group synced"
            )
            alert = None
            alert_line = None
            deadline = time.monotonic() + 40
            while time.monotonic() < deadline:
                assert all(process.poll() is None for process in processes)
                with event_file.open("a") as destination:
                    destination.write(event)
                time.sleep(1)
                alerts = manager / "logs/alerts/alerts.json"
                if alerts.exists():
                    for line in alerts.read_text().splitlines():
                        candidate = json.loads(line)
                        if (
                            candidate.get("data", {}).get("securityops_fixture")
                            == token
                        ):
                            alert = candidate
                            alert_line = line
                            break
                if alert is not None:
                    break
            assert alert is not None, "agent event never reached manager alert output"
            assert alert_line is not None
            assert alert["rule"]["id"] == "100001"
            assert alert["agent"]["id"] == "001"
            assert alert["decoder"]["name"] == "json"
            assert alert["rule"]["mitre"]["id"] == ["T1059"]
            assert alert["rule"]["mitre"]["technique"]
            assert alert["rule"]["mitre"]["tactic"]
            print("PASS: genuine manager alert includes native MITRE data enrichment")
            deadline = time.monotonic() + 60
            while True:
                assert all(process.poll() is None for process in processes)
                status, response = api_request(
                    opener, "/syscollector/001/hardware", authorization
                )
                if status == 200:
                    inventory = json.loads(response)["data"]
                    if inventory["total_affected_items"]:
                        assert inventory["affected_items"][0]["cpu"]["cores"] > 0
                        break
                assert time.monotonic() < deadline, (
                    "guest-only hardware inventory never arrived"
                )
                time.sleep(1)
            print(
                "PASS: native syscollector publishes disposable guest inventory through authenticated API"
            )
            # Preserve evidence of unchanged privilege separation.
            for process in processes[:3]:
                status = Path(f"/proc/{process.pid}/status").read_text()
                assert f"Uid:\t{uid}\t{uid}\t{uid}\t{uid}" in status
                assert Path(f"/proc/{process.pid}/root").resolve() == manager
            api_status = Path(f"/proc/{api.pid}/status").read_text()
            assert f"Uid:\t{uid}\t{uid}\t{uid}\t{uid}" in api_status
            print(
                "PASS: local agent → encrypted remoted → unprivileged analysisd → JSON alert"
            )
            if arguments.alert_copy:
                arguments.alert_copy.write_text(alert_line + "\n")
            if all(integration):
                # Keep these generated credentials separate from root-owned
                # component state so the search fixture's dedicated UID can
                # read only its own private contract.  No secret enters argv.
                with tempfile.TemporaryDirectory(
                    prefix="securityops-wazuh-integration-"
                ) as temporary:
                    shared = Path(temporary)
                    shared.chmod(0o700)
                    os.chown(shared, uid, gid)
                    ca_copy = shared / "manager-ca.pem"
                    shutil.copyfile(certificate, ca_copy)
                    selected = shared / "selected-alert.json"
                    selected.write_text(alert_line + "\n")
                    contract = shared / "integration.json"
                    contract.write_text(
                        json.dumps(
                            {
                                "api_url": "https://127.0.0.1:55000",
                                "manager_ca": str(ca_copy),
                                "api_user": "wazuh-wui",
                                "api_password": users["default_users"]["wazuh-wui"][
                                    "password"
                                ],
                                "alert_path": str(selected),
                                "event_token": token,
                            }
                        )
                    )
                    for asset in (ca_copy, selected, contract):
                        asset.chmod(0o600)
                        os.chown(asset, uid, gid)
                        assert asset.stat().st_mode & 0o777 == 0o600
                    subprocess.run(
                        [
                            sys.executable,
                            str(arguments.integration_fixture),
                            str(arguments.indexer),
                            str(arguments.dashboard),
                            str(arguments.filebeat),
                            "--runtime",
                            "--integration-config",
                            str(contract),
                        ],
                        user=uid,
                        group=gid,
                        extra_groups=[],
                        check=True,
                        timeout=900,
                    )
                    assert all(process.poll() is None for process in processes)
                    print(
                        "PASS: complete search fixture ran against live manager API and genuine alert"
                    )
            assert all(process.poll() is None for process in processes)
            endpoint_log = (parent / "agent-wazuh-agentd.log").read_text()
            assert "At reloadAgent()" not in endpoint_log, endpoint_log
            assert (
                "Agent is reloading due to shared configuration changes"
                not in endpoint_log
            )
            assert not (agent / "queue/alerts/execq").exists()
            assert (
                "Active response disabled"
                in (parent / "agent-wazuh-execd.log").read_text()
            )
            print(
                "PASS: synchronized baseline retains all owned processes without reload or actions"
            )
        finally:
            for process in reversed(processes):
                stop(process)
            for log in logs:
                log.seek(0)
                print(log.read())
                log.close()
            for mount in reversed(mounted):
                subprocess.run(["umount", str(mount)], check=True)


if __name__ == "__main__":
    main()
