"""Exercise installed Wazuh search commands and explicit-state refusals."""

import argparse
import base64
import importlib.util
import json
import os
import secrets
import shutil
import signal
import socket
import ssl
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

import bcrypt


def check_layout(indexer: Path, dashboard: Path, filebeat: Path) -> None:
    """Catch missing commands, implicit mutable state, and demo users."""
    commands = (
        indexer / "bin/wazuh-indexer",
        indexer / "bin/wazuh-indexer-securityadmin",
        dashboard / "bin/wazuh-dashboard",
        filebeat / "bin/wazuh-filebeat",
    )
    for command in commands:
        assert command.is_file() and os.access(command, os.X_OK), command
    assert not (indexer / "share/wazuh-indexer/config/internal_users.yml").exists()
    assert not (
        indexer / "share/wazuh-indexer/config/opensearch-security/internal_users.yml"
    ).exists()
    assert (filebeat / "share/doc/filebeat/WAZUH-MODULE-LICENSE").is_file(), (
        "Matching Wazuh module license was not retained"
    )
    for package in (indexer, dashboard, filebeat):
        assert (
            package / "share/doc" / package.name.split("-", 1)[-1]
        ).exists() or list((package / "share/doc").glob("*/SOURCE-LINKS")), package
    with tempfile.TemporaryDirectory(prefix="wazuh-search-refusal-") as name:
        parent = Path(name)
        env = dict(os.environ)
        env.pop("WAZUH_SEARCH_STATE", None)
        for command in (commands[0], commands[2], commands[3]):
            result = subprocess.run(
                [str(command)],
                env=env,
                cwd=parent,
                capture_output=True,
                timeout=20,
                check=False,
            )
            assert result.returncode != 0, command
            assert b"WAZUH_SEARCH_STATE" in result.stderr, result.stderr
        env["PYTHONHOME"] = str(parent / "ambient-python-home")
        env["PYTHONPATH"] = str(parent / "ambient-python-packages")
        for command in (commands[0], commands[2], commands[3]):
            result = subprocess.run(
                [str(command)],
                env=env,
                cwd=parent,
                capture_output=True,
                timeout=20,
                check=False,
            )
            assert result.returncode == 2 and b"WAZUH_SEARCH_STATE" in result.stderr, (
                "Launcher did not isolate Python from ambient startup/package paths"
            )
        env.pop("PYTHONHOME")
        env.pop("PYTHONPATH")
        assert not list(parent.iterdir()), "Refusal created implicit state"
        for forbidden in ("/", "/gnu/store", str(parent / "missing")):
            env["WAZUH_SEARCH_STATE"] = forbidden
            for command in (commands[0], commands[2], commands[3]):
                result = subprocess.run(
                    [str(command)],
                    env=env,
                    capture_output=True,
                    timeout=20,
                    check=False,
                )
                assert result.returncode != 0, (command, forbidden)
    print("PASS installed commands, retained source notices, explicit-state refusal")


def run(command: list[str], env: dict[str, str] | None = None) -> None:
    result = subprocess.run(
        command, env=env, capture_output=True, check=False, timeout=90
    )
    # Never include command arguments/configuration in errors: they may identify
    # private credential files. Fixture-generated passwords are never argv.
    assert result.returncode == 0, (
        Path(command[0]).name,
        result.returncode,
        result.stderr.decode(errors="replace"),
    )


def write(path: Path, content: str) -> None:
    path.write_text(content, encoding="utf-8")
    path.chmod(0o600)


def check_guard(script: Path) -> None:
    """Catch credential file escapes/readability before executing any backend."""
    with tempfile.TemporaryDirectory(prefix="wazuh-seccomp-policy-") as temporary:
        root = Path(temporary)
        selected = state(root, "filebeat")
        env = dict(os.environ, WAZUH_SEARCH_STATE=str(selected))
        for sandbox in (
            "seccomp.enabled: false\n",
            'seccomp:\n  enabled: "false"\n',
            "seccomp:\n  default_action: allow\n  syscalls: []\n",
        ):
            write(selected / "config/filebeat.yml", sandbox)
            result = subprocess.run(
                [
                    sys.executable,
                    str(script),
                    "filebeat",
                    str(root / "absent-backend"),
                    str(root / "absent-runtime"),
                ],
                env=env,
                capture_output=True,
                check=False,
                timeout=20,
            )
            assert (
                result.returncode == 2 and b"default-deny seccomp" in result.stderr
            ), "Disabled/replaced native seccomp policy was not refused"
    with tempfile.TemporaryDirectory(prefix="wazuh-search-policy-") as temporary:
        root = Path(temporary)
        selected = state(root, "indexer")
        write(
            selected / "config/opensearch.yml",
            "plugins.security.ssl.http.enabled: true\n"
            "plugins.security.ssl.transport.enforce_hostname_verification: true\n",
        )
        users = selected / "config/opensearch-security"
        users.mkdir(mode=0o700)
        external = root / "outside-users.yml"
        write(external, "_meta: {type: internalusers, config_version: 2}\n")
        (users / "internal_users.yml").symlink_to(external)
        env = dict(os.environ, WAZUH_SEARCH_STATE=str(selected))
        indexer_command = [
            sys.executable,
            str(script),
            "securityadmin",
            str(root / "absent-backend"),
            str(root / "absent-runtime"),
        ]
        for option in (
            "allow_unsafe_democertificates",
            "allow_default_init_securityindex",
        ):
            write(
                selected / "config/opensearch.yml",
                "plugins.security.ssl.http.enabled: true\n"
                "plugins.security.ssl.transport.enforce_hostname_verification: true\n"
                f"plugins.security.{option}: true\n",
            )
            result = subprocess.run(
                indexer_command, env=env, capture_output=True, check=False, timeout=20
            )
            assert result.returncode == 2 and b"default or demo" in result.stderr, (
                "Default/demo security initialization was not refused"
            )
        for unsafe in (
            "plugins:\n  security:\n    disabled: true\n",
            "plugins.security:\n  disabled: true\n",
            (
                "plugins.security.disabled: false\n"
                "plugins:\n  security:\n    disabled: true\n"
            ),
        ):
            write(
                selected / "config/opensearch.yml",
                "plugins.security.ssl.http.enabled: true\n"
                "plugins.security.ssl.transport.enforce_hostname_verification: true\n"
                + unsafe,
            )
            result = subprocess.run(
                indexer_command, env=env, capture_output=True, check=False, timeout=20
            )
            assert result.returncode == 2 and (
                b"authentication cannot be disabled" in result.stderr
                or b"ambiguous dotted/nested" in result.stderr
            ), "Nested/ambiguous indexer authentication toggle escaped policy"
        write(
            selected / "config/opensearch.yml",
            'plugins.security.disabled: "true"\n'
            "plugins.security.ssl.http.enabled: true\n"
            "plugins.security.ssl.transport.enforce_hostname_verification: true\n",
        )
        result = subprocess.run(
            indexer_command, env=env, capture_output=True, check=False, timeout=20
        )
        assert (
            result.returncode == 2
            and b"authentication cannot be disabled" in result.stderr
        ), "string-valued security-disable configuration was not refused"
        write(
            selected / "config/opensearch.yml",
            "plugins.security.ssl.http.enabled: true\n"
            "plugins.security.ssl.transport.enforce_hostname_verification: true\n",
        )
        result = subprocess.run(
            [
                sys.executable,
                str(script),
                "securityadmin",
                str(root / "absent-backend"),
                str(root / "absent-runtime"),
            ],
            env=env,
            capture_output=True,
            check=False,
            timeout=20,
        )
        assert (
            result.returncode == 2 and b"beneath WAZUH_SEARCH_STATE" in result.stderr
        ), "users symlink escape was not refused before executing the backend"
        visual = state(root, "dashboard")
        config = visual / "config/opensearch_dashboards.yml"
        write(
            config,
            "server.ssl.enabled: true\nopensearch.ssl.verificationMode: full\n"
            "opensearch.hosts: [https://localhost:9200]\nopensearch.username: fixture-user\n"
            "opensearch.password: " + json.dumps(secrets.token_urlsafe(24)) + "\n",
        )
        config.chmod(0o644)
        env["WAZUH_SEARCH_STATE"] = str(visual)
        result = subprocess.run(
            [
                sys.executable,
                str(script),
                "dashboard",
                str(root / "absent-backend"),
                str(root / "absent-runtime"),
            ],
            env=env,
            capture_output=True,
            check=False,
            timeout=20,
        )
        assert result.returncode == 2 and b"private credential" in result.stderr, (
            "group/world-readable credentials were not refused"
        )
        config.chmod(0o600)
        baseline = config.read_text(encoding="utf-8")
        write(
            config,
            baseline
            + "opensearch_security:\n  auth:\n    anonymous_auth_enabled: true\n",
        )
        result = subprocess.run(
            [
                sys.executable,
                str(script),
                "dashboard",
                str(root / "absent-backend"),
                str(root / "absent-runtime"),
            ],
            env=env,
            capture_output=True,
            timeout=20,
            check=False,
        )
        assert result.returncode == 2 and b"anonymous" in result.stderr, (
            "Nested dashboard anonymous authentication escaped policy"
        )
        write(config, baseline)
        api = visual / "data/wazuh/config"
        api.mkdir(parents=True, mode=0o700)
        write(
            api / "wazuh.yml",
            "hosts:\n  - fixture:\n      url: http://localhost\n"
            "      username: fixture-api\n      password: fixture-only\n",
        )
        command = [
            sys.executable,
            str(script),
            "dashboard",
            str(root / "absent-backend"),
            str(root / "absent-runtime"),
        ]
        result = subprocess.run(
            command, env=env, capture_output=True, timeout=20, check=False
        )
        assert result.returncode == 2 and b"HTTPS manager API" in result.stderr, (
            "plaintext manager credentials were not refused before backend startup"
        )
        write(
            api / "wazuh.yml",
            "hosts:\n  - fixture:\n      url: https://localhost\n"
            "      username: fixture-api\n      password: fixture-only\n",
        )
        (visual / "config/manager-ca.pem").symlink_to(external)
        result = subprocess.run(
            command, env=env, capture_output=True, timeout=20, check=False
        )
        assert (
            result.returncode == 2 and b"beneath WAZUH_SEARCH_STATE" in result.stderr
        ), "manager CA symlink escape was not refused before backend startup"
    specification = importlib.util.spec_from_file_location("wazuh_search_guard", script)
    assert specification and specification.loader
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    tunables = getattr(module, "filebeat_tunables", None)
    assert callable(tunables), "Filebeat process-local rseq compatibility is missing"
    assert tunables("") == "glibc.pthread.rseq=0"
    assert (
        tunables(
            "glibc.malloc.check=3:glibc.pthread.rseq=1:glibc.malloc.trim_threshold=8192"
        )
        == "glibc.malloc.check=3:glibc.malloc.trim_threshold=8192:glibc.pthread.rseq=0"
    )
    assert (
        tunables("glibc.pthread.rseq=1:glibc.pthread.rseq_extra=7:glibc.pthread.rseq=2")
        == "glibc.pthread.rseq_extra=7:glibc.pthread.rseq=0"
    )
    lookup = getattr(module, "filebeat_value", None)
    assert callable(lookup), "Filebeat nested output namespace lookup is missing"
    assert lookup(
        {"output.elasticsearch": {"username": "fixture-user"}}, "username"
    ) == ("fixture-user")
    assert lookup(
        {"output": {"elasticsearch": {"hosts": ["https://localhost:9200"]}}}, "hosts"
    ) == ["https://localhost:9200"]
    assert (
        lookup(
            {"output.elasticsearch": {"ssl": {"verification_mode": "full"}}},
            "ssl.verification_mode",
        )
        == "full"
    )
    verify = getattr(module, "verify_module", None)
    assert callable(verify), "Filebeat exact-module ownership verification is missing"
    with tempfile.TemporaryDirectory(prefix="wazuh-module-integrity-") as temporary:
        root = Path(temporary)
        packaged = root / "packaged"
        (packaged / "module/wazuh").mkdir(parents=True, mode=0o700)
        write(packaged / "module/wazuh/manifest.yml", "module: fixture\n")
        selected = state(root, "state")
        (selected / "module/wazuh").mkdir(parents=True, mode=0o700)
        manifest = selected / "module/wazuh/manifest.yml"
        write(manifest, "module: fixture\n")
        verify(packaged, selected)
        write(manifest, "module: modified-fixture\n")
        try:
            verify(packaged, selected)
        except SystemExit as error:
            assert error.code == 2
        else:
            raise AssertionError("Modified Filebeat module configuration was accepted")
    with tempfile.TemporaryDirectory(prefix="wazuh-search-ancestor-") as temporary:
        root = Path(temporary)
        shared = root / "unsafe-parent"
        shared.mkdir(mode=0o777)
        shared.chmod(0o777)
        selected = state(shared, "indexer")
        env = dict(os.environ, WAZUH_SEARCH_STATE=str(selected))
        result = subprocess.run(
            [
                sys.executable,
                str(script),
                "securityadmin",
                str(root / "absent-backend"),
                str(root / "absent-runtime"),
            ],
            env=env,
            capture_output=True,
            check=False,
            timeout=20,
        )
        assert result.returncode == 2 and b"unsafe state ancestor" in result.stderr, (
            "a replaceable state ancestor was not refused"
        )
    print("PASS credential file containment and private permissions")


def certificate(root: Path, name: str, subject: str, ca: bool = False) -> None:
    key, cert = root / f"{name}-key.pem", root / f"{name}.pem"
    run(
        [
            "openssl",
            "genpkey",
            "-algorithm",
            "RSA",
            "-pkeyopt",
            "rsa_keygen_bits:2048",
            "-out",
            str(key),
        ]
    )
    key.chmod(0o600)
    if ca:
        run(
            [
                "openssl",
                "req",
                "-new",
                "-x509",
                "-key",
                str(key),
                "-out",
                str(cert),
                "-days",
                "1",
                "-subj",
                subject,
                "-addext",
                "basicConstraints=critical,CA:TRUE",
                "-addext",
                "keyUsage=critical,keyCertSign,cRLSign",
            ]
        )
    else:
        csr, extension = root / f"{name}.csr", root / f"{name}.ext"
        write(
            extension,
            "basicConstraints=CA:FALSE\nkeyUsage=digitalSignature,keyEncipherment\n"
            "extendedKeyUsage=serverAuth,clientAuth\nsubjectAltName=DNS:localhost,IP:127.0.0.1\n",
        )
        run(
            [
                "openssl",
                "req",
                "-new",
                "-key",
                str(key),
                "-out",
                str(csr),
                "-subj",
                subject,
            ]
        )
        run(
            [
                "openssl",
                "x509",
                "-req",
                "-in",
                str(csr),
                "-CA",
                str(root / "ca.pem"),
                "-CAkey",
                str(root / "ca-key.pem"),
                "-CAcreateserial",
                "-out",
                str(cert),
                "-days",
                "1",
                "-extfile",
                str(extension),
            ]
        )


def request(
    url: str,
    ca: Path,
    credentials: tuple[str, str] | None = None,
    method: str = "GET",
    body: dict[str, object] | None = None,
    extra_headers: dict[str, str] | None = None,
) -> tuple[int, bytes]:
    headers = {"Content-Type": "application/json"}
    headers.update(extra_headers or {})
    if credentials:
        headers["Authorization"] = (
            "Basic " + base64.b64encode(":".join(credentials).encode()).decode()
        )
    query = urllib.request.Request(
        url,
        headers=headers,
        method=method,
        data=json.dumps(body).encode() if body is not None else None,
    )
    context = ssl.create_default_context(cafile=str(ca))
    try:
        with urllib.request.urlopen(query, context=context, timeout=5) as response:
            return response.status, response.read()
    except urllib.error.HTTPError as error:
        return error.code, error.read()


def port() -> int:
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        return listener.getsockname()[1]


def state(root: Path, name: str) -> Path:
    destination = root / name
    destination.mkdir(mode=0o700)
    for directory in ("config", "data", "logs"):
        (destination / directory).mkdir(mode=0o700)
    return destination


def integration_settings(configuration: Path) -> dict:
    """Read only explicitly supplied fresh fixture credentials, never operator state."""
    resolved = configuration.resolve(strict=True)
    assert resolved.stat().st_uid == os.getuid()
    assert not resolved.stat().st_mode & 0o077
    assert resolved.stat().st_size <= 65536
    settings = json.loads(resolved.read_text(encoding="utf-8"))
    assert isinstance(settings, dict)
    assert all(
        key in settings
        for key in (
            "api_url",
            "manager_ca",
            "api_user",
            "api_password",
            "alert_path",
            "event_token",
        )
    ), "Incomplete private integration fixture contract"
    api = urllib.parse.urlsplit(settings["api_url"])
    assert api.scheme == "https" and api.hostname in ("localhost", "127.0.0.1")
    assert api.port and not api.username and not api.password
    assert not api.query and not api.fragment and api.path in ("", "/")
    assert settings["api_user"] == "wazuh-wui" and settings["api_password"]
    for key in ("manager_ca", "alert_path"):
        supplied = Path(settings[key]).resolve(strict=True)
        assert supplied.is_relative_to(resolved.parent)
        assert supplied.stat().st_uid == os.getuid()
        assert not supplied.stat().st_mode & 0o077
    return settings


def check_live_client(dashboard: Path, integration: dict, wrong_ca: Path) -> None:
    """Verify the installed client against the still-running real manager API."""
    api = urllib.parse.urlsplit(integration["api_url"])
    native = dashboard / "share/wazuh-dashboard"
    host = {
        "url": f"https://{api.hostname}",
        "port": api.port,
        "username": integration["api_user"],
        "password": integration["api_password"],
    }
    for mode, ca in (
        ("untrusted", wrong_ca),
        ("live", Path(integration["manager_ca"])),
    ):
        env = dict(os.environ, NODE_EXTRA_CA_CERTS=str(ca))
        for ambient in ("NODE_TLS_REJECT_UNAUTHORIZED", "NODE_OPTIONS"):
            env.pop(ambient, None)
        completed = subprocess.run(
            [
                str(native / "node/bin/node"),
                str(Path(__file__).with_name("wazuh-manager-client-tls.cjs")),
                str(native / "plugins/wazuhCore/server/services/server-api-client.js"),
            ],
            input=json.dumps({"mode": mode, "host": host}).encode(),
            env=env,
            capture_output=True,
            check=False,
            timeout=45,
        )
        assert completed.returncode == 0, (
            f"Live manager API installed-client {mode} TLS failure"
        )
    print(
        "PASS actual live manager API: installed Node client CA refusal/authenticated4.14.8"
    )


def check_runtime(
    indexer: Path,
    dashboard: Path,
    filebeat: Path,
    alert_file: Path | None = None,
    trace_filebeat: Path | None = None,
    integration: dict | None = None,
) -> None:
    """Catch missing TLS/authentication and a broken real forwarding closure."""
    interfaces = {
        line.partition(":")[0].strip()
        for line in Path("/proc/net/dev").read_text().splitlines()
        if ":" in line
    }
    assert interfaces == {"lo"}, "Run inside a private no-network container/guest"
    assert os.getuid() != 0, "Search services require an unprivileged fixture account"
    processes: list[subprocess.Popen[bytes]] = []
    streams = []
    with tempfile.TemporaryDirectory(prefix="wazuh-search-runtime-") as temporary:
        root = Path(temporary)
        certificates = root / "certificates"
        certificates.mkdir(mode=0o700)
        certificate(certificates, "ca", "/CN=SecurityOpsFixtureCA", ca=True)
        certificate(certificates, "node", "/CN=localhost")
        certificate(certificates, "admin", "/CN=SearchAdmin")
        certificate(certificates, "wrong-ca", "/CN=UnrelatedFixtureCA", ca=True)
        ca = certificates / "ca.pem"
        user = ("fixture-user", secrets.token_urlsafe(24))
        dashboard_user = ("fixture-dashboard", secrets.token_urlsafe(24))
        index_state = state(root, "indexer")
        examples = indexer / "share/doc/wazuh-indexer/config-examples"
        shutil.copytree(examples, index_state / "config", dirs_exist_ok=True)
        # Store examples are immutable.  Only these freshly copied fixture
        # configurations become private mutable state; inputs stay untouched.
        for copied in (index_state / "config").rglob("*"):
            copied.chmod(0o700 if copied.is_dir() else 0o600)
        (index_state / "config").chmod(0o700)
        shutil.copytree(certificates, index_state / "config/certs")
        users = "_meta:\n  type: internalusers\n  config_version: 2\n"
        for account, roles in ((user, "admin"), (dashboard_user, "kibana_server")):
            password_hash = bcrypt.hashpw(
                account[1].encode(), bcrypt.gensalt(rounds=12, prefix=b"2a")
            ).decode()
            users += f"{account[0]}:\n  hash: {json.dumps(password_hash)}\n  backend_roles: [{roles}]\n"
        write(index_state / "config/opensearch-security/internal_users.yml", users)
        mapping = index_state / "config/opensearch-security/roles_mapping.yml"
        original_mapping = mapping.read_text()
        service_user = '  - "kibanaserver"\n'
        assert original_mapping.count(service_user) == 2
        # Preserve both upstream service roles (kibana_server and
        # manage_wazuh_index); replace only their existing username bindings.
        write(
            mapping,
            original_mapping.replace(service_user, f'  - "{dashboard_user[0]}"\n'),
        )
        security_config = index_state / "config/opensearch-security/config.yml"
        original_security = security_config.read_text()
        assert original_security.count("  dynamic:\n") == 1
        write(
            security_config,
            original_security.replace(
                "  dynamic:\n",
                "  dynamic:\n    kibana:\n"
                f"      server_username: {dashboard_user[0]}\n",
            ),
        )
        index_port, transport_port, dashboard_port = port(), port(), port()
        url = f"https://localhost:{index_port}"
        write(
            index_state / "config/opensearch.yml",
            f"""cluster.name: securityops-wazuh-test
node.name: node-1
network.host: 127.0.0.1
http.port: {index_port}
transport.port: {transport_port}
discovery.type: single-node
plugins:
  security:
    ssl:
      http:
        enabled: true
      transport:
        enforce_hostname_verification: true
plugins.security.ssl.http.pemcert_filepath: certs/node.pem
plugins.security.ssl.http.pemkey_filepath: certs/node-key.pem
plugins.security.ssl.http.pemtrustedcas_filepath: certs/ca.pem
plugins.security.ssl.transport.pemcert_filepath: certs/node.pem
plugins.security.ssl.transport.pemkey_filepath: certs/node-key.pem
plugins.security.ssl.transport.pemtrustedcas_filepath: certs/ca.pem
plugins.security.authcz.admin_dn: [CN=SearchAdmin]
plugins.security.nodes_dn: [CN=localhost]
plugins.security.restapi.roles_enabled: [all_access, security_rest_api_access]
compatibility.override_main_response_version: true
""",
        )
        options = index_state / "config/jvm.options"
        write(
            options,
            options.read_text()
            .replace("-Xms1g", "-Xms512m")
            .replace("-Xmx1g", "-Xmx512m")
            .replace("/var/log/wazuh-indexer", str(index_state / "logs"))
            .replace("/var/lib/wazuh-indexer", str(index_state / "data")),
        )

        def start(
            command: Path, selected_state: Path, label: str
        ) -> subprocess.Popen[bytes]:
            stream = (root / f"{label}.log").open("wb")
            streams.append(stream)
            env = dict(os.environ, WAZUH_SEARCH_STATE=str(selected_state))
            if label == "dashboard":
                env.update(
                    NODE_TLS_REJECT_UNAUTHORIZED="0",
                    NODE_OPTIONS="--require=/fixture-ambient-startup-must-not-run.cjs",
                    NODE_EXTRA_CA_CERTS=str(certificates / "wrong-ca.pem"),
                )
            if label == "filebeat":
                env["GLIBC_TUNABLES"] = (
                    "glibc.malloc.trim_threshold=131072:glibc.pthread.rseq=1"
                )
            invocation = [str(command)]
            if label == "filebeat" and trace_filebeat:
                invocation = [
                    str(trace_filebeat),
                    "-f",
                    "-e",
                    "trace=clone,clone3,rseq,prctl,seccomp",
                    "-o",
                    str(root / "filebeat.trace"),
                    *invocation,
                ]
            process = subprocess.Popen(
                invocation,
                env=env,
                stdout=stream,
                stderr=subprocess.STDOUT,
                start_new_session=True,
            )
            processes.append(process)
            return process

        try:
            server = start(indexer / "bin/wazuh-indexer", index_state, "indexer")
            deadline = time.monotonic() + 150
            while True:
                assert server.poll() is None, (
                    "Indexer exited before authenticated startup"
                )
                try:
                    status, _ = request(url, ca)
                    if status in (401, 503):
                        break
                except (OSError, urllib.error.URLError):
                    pass
                assert time.monotonic() < deadline, "Indexer startup timed out"
                time.sleep(1)
            env = dict(os.environ, WAZUH_SEARCH_STATE=str(index_state))
            run(
                [
                    str(indexer / "bin/wazuh-indexer-securityadmin"),
                    "-cd",
                    str(index_state / "config/opensearch-security"),
                    "-cacert",
                    str(ca),
                    "-cert",
                    str(certificates / "admin.pem"),
                    "-key",
                    str(certificates / "admin-key.pem"),
                    "-h",
                    "localhost",
                    "-p",
                    str(index_port),
                    "-cn",
                    "securityops-wazuh-test",
                ],
                env,
            )
            # Securityadmin returns after writing configuration, before the
            # server's initial asynchronous security reload necessarily ends.
            deadline = time.monotonic() + 30
            while True:
                status, _ = request(url, ca)
                if status == 401:
                    break
                assert status == 503 and time.monotonic() < deadline, (
                    "Indexer did not finish security initialization",
                    status,
                )
                time.sleep(0.5)
            assert request(url, ca, (user[0], "wrong-password"))[0] == 401
            assert request(url, ca, user)[0] == 200
            try:
                request(url, certificates / "wrong-ca.pem", user)
            except urllib.error.URLError as error:
                assert isinstance(error.reason, ssl.SSLCertVerificationError)
            else:
                raise AssertionError("Indexer accepted an untrusted certificate")
            inserted = request(
                url + "/securityops-fixture/_doc/1?refresh=true",
                ca,
                user,
                "PUT",
                {"message": "synthetic authenticated document"},
            )
            assert inserted[0] in (200, 201), inserted[0]
            status, body = request(url + "/securityops-fixture/_doc/1", ca, user)
            assert status == 200 and json.loads(body)["_source"]["message"] == (
                "synthetic authenticated document"
            )
            print(
                "PASS indexer authenticated insert/query, bad/missing credentials, untrusted CA"
            )

            forwarding = state(root, "filebeat")
            shutil.copytree(
                filebeat / "share/filebeat/module/wazuh", forwarding / "module/wazuh"
            )
            (forwarding / "module").chmod(0o700)
            for copied in (forwarding / "module").rglob("*"):
                copied.chmod(0o700 if copied.is_dir() else 0o600)
            alert_id = secrets.token_hex(12)
            alert = {
                # Match analysisd's milliseconds and strftime %z exactly.
                "timestamp": datetime.now(timezone.utc)
                .isoformat(timespec="milliseconds")
                .replace("+00:00", "+0000"),
                "rule": {
                    "id": "100001",
                    "level": 5,
                    "description": "Synthetic test event",
                    "groups": ["securityops_fixture"],
                    "firedtimes": 1,
                },
                "agent": {"id": "001", "name": "fixture-agent", "ip": "127.0.0.1"},
                "manager": {"name": "fixture-manager"},
                "id": alert_id,
                "full_log": "SecurityOps synthetic event",
                "decoder": {"name": "json"},
                "location": "fixture-log",
            }
            if alert_file:
                assert alert_file.stat().st_size <= 2 * 1024 * 1024
                lines = alert_file.read_text(encoding="utf-8").splitlines()
                assert len(lines) == 1, "Supply only the verified guest fixture event"
                alert = json.loads(lines[0])
                assert isinstance(alert, dict) and isinstance(alert.get("id"), str)
                assert isinstance(alert.get("agent"), dict)
                assert isinstance(alert.get("rule"), dict)
                assert all(key in alert["agent"] for key in ("id", "name"))
                assert "id" in alert["rule"] and "full_log" in alert
                alert_id = alert["id"]
                if integration:
                    assert integration["event_token"] in alert["full_log"], (
                        "Selected manager event does not contain the real guest fixture token"
                    )
            alerts = root / "alerts.json"
            date_processor = next(
                processor
                for processor in json.loads(
                    (
                        filebeat
                        / "share/filebeat/module/wazuh/alerts/ingest/pipeline.json"
                    ).read_text()
                )["processors"]
                if "date_index_name" in processor
            )
            status, body = request(
                url + "/_ingest/pipeline/_simulate",
                ca,
                user,
                "POST",
                {
                    "pipeline": {"processors": [date_processor]},
                    "docs": [
                        {
                            "_source": {
                                "timestamp": alert["timestamp"],
                                "fields": {"index_prefix": "wazuh-alerts-4.x-"},
                            }
                        },
                        {
                            "_source": {
                                "timestamp": "2026-10-08T00:00:00.123456+00:00",
                                "fields": {"index_prefix": "wazuh-alerts-4.x-"},
                            }
                        },
                    ],
                },
            )
            assert status == 200 and "doc" in json.loads(body)["docs"][0], (
                "Fixture timestamp does not match the native Wazuh date-index processor"
            )
            assert "error" in json.loads(body)["docs"][1], (
                "Malformed synthetic timestamp unexpectedly passed the native processor"
            )
            write(alerts, json.dumps(alert) + "\n")
            write(
                forwarding / "config/filebeat.yml",
                f"""filebeat.modules:
  - module: wazuh
    alerts:
      enabled: true
      var.paths: [{json.dumps(str(alerts))}]
    archives:
      enabled: false
setup.template.json.enabled: true
setup.template.json.path: {json.dumps(str(filebeat / "share/filebeat/wazuh-template.json"))}
setup.template.json.name: wazuh
setup.template.overwrite: true
setup.ilm.enabled: false
output.elasticsearch:
  hosts: [{json.dumps(url)}]
  username: {user[0]}
  password: {json.dumps(user[1])}
  ssl:
    verification_mode: full
    certificate_authorities: [{json.dumps(str(ca))}]
logging.metrics.enabled: false
logging.level: info
""",
            )
            env = dict(os.environ, WAZUH_SEARCH_STATE=str(forwarding))
            run([str(filebeat / "bin/wazuh-filebeat"), "test", "config"], env)
            run([str(filebeat / "bin/wazuh-filebeat"), "test", "output"], env)
            shipper = start(filebeat / "bin/wazuh-filebeat", forwarding, "filebeat")
            deadline = time.monotonic() + 90
            while True:
                assert shipper.poll() is None, "Filebeat exited before forwarding"
                status, body = request(
                    url
                    + "/wazuh-alerts-*/_search?q="
                    + urllib.parse.quote("id:" + alert_id, safe=""),
                    ca,
                    user,
                )
                if status == 200 and json.loads(body)["hits"]["hits"]:
                    document = json.loads(body)["hits"]["hits"][0]["_source"]
                    assert document["agent"]["name"] == alert["agent"]["name"]
                    assert document["agent"]["id"] == alert["agent"]["id"]
                    assert document["rule"]["id"] == alert["rule"]["id"]
                    assert document["full_log"] == alert["full_log"]
                    break
                assert time.monotonic() < deadline, (
                    "Actual Wazuh module forwarding timed out"
                )
                time.sleep(1)
            print("PASS real Filebeat Wazuh module forwarded original alert fields")
            native_executable = (filebeat / "share/filebeat/bin/filebeat").resolve(
                strict=True
            )
            native_pid = shipper.pid
            if trace_filebeat:
                # Inspect only direct children of the fixture's own tracer,
                # never unrelated host/container processes.
                children = {
                    int(child)
                    for task in Path(f"/proc/{shipper.pid}/task").iterdir()
                    for child in (task / "children").read_text().split()
                }
                candidates = []
                for child in children:
                    proc = Path(f"/proc/{child}")
                    try:
                        if (proc / "exe").resolve(strict=True) == native_executable:
                            fields = dict(
                                line.split(":", 1)
                                for line in (proc / "status").read_text().splitlines()
                                if ":" in line
                            )
                            assert int(fields["PPid"]) == shipper.pid
                            assert {int(uid) for uid in fields["Uid"].split()} == {
                                os.getuid()
                            }
                            candidates.append(child)
                    except (FileNotFoundError, ProcessLookupError):
                        continue
                assert len(candidates) == 1, "Expected exactly one owned native shipper"
                native_pid = candidates[0]
            native_proc = Path(f"/proc/{native_pid}")
            assert (native_proc / "exe").resolve(strict=True) == native_executable
            status_fields = dict(
                line.split(":", 1)
                for line in (native_proc / "status").read_text().splitlines()
                if ":" in line
            )
            assert {int(uid) for uid in status_fields["Uid"].split()} == {os.getuid()}
            assert status_fields["Seccomp"].strip() == "2"
            assert status_fields["NoNewPrivs"].strip() == "1"
            assert "glibc-for-wazuh-filebeat" in (native_proc / "maps").read_text()
            loaded_environment = dict(
                item.split(b"=", 1)
                for item in (native_proc / "environ").read_bytes().split(b"\0")
                if b"=" in item
            )
            assert loaded_environment[b"GLIBC_TUNABLES"].split(b":") == [
                b"glibc.malloc.trim_threshold=131072",
                b"glibc.pthread.rseq=0",
            ], "Process-local rseq compatibility lost unrelated caller tunables"
            print("PASS Filebeat private libc, native seccomp filter and no_new_privs")
            print("PASS process-local rseq=0 preserves unrelated libc tunable")
            assert request(url + "/.kibana", ca, dashboard_user)[0] in (200, 404), (
                "Upstream restricted dashboard service identity lacks saved-object access"
            )

            visual = state(root, "dashboard")
            manager_ca = Path(integration["manager_ca"]) if integration else ca
            shutil.copyfile(manager_ca, visual / "config/manager-ca.pem")
            (visual / "config/manager-ca.pem").chmod(0o600)
            api_config = visual / "data/wazuh/config"
            api_config.mkdir(parents=True, mode=0o700)
            api_url = (
                urllib.parse.urlsplit(integration["api_url"]) if integration else None
            )
            write(
                api_config / "wazuh.yml",
                "hosts:\n  - fixture:\n      url: "
                + json.dumps(
                    f"https://{api_url.hostname}" if api_url else "https://localhost"
                )
                + f"\n      port: {api_url.port if api_url else 55000}\n      username: "
                + json.dumps(integration["api_user"] if integration else "fixture-api")
                + "\n      password: "
                + json.dumps(
                    integration["api_password"]
                    if integration
                    else secrets.token_urlsafe(24)
                )
                + "\n      run_as: true\n",
            )
            write(
                visual / "config/opensearch_dashboards.yml",
                f"""server.host: 127.0.0.1
server.port: {dashboard_port}
server.ssl.enabled: true
server.ssl.key: {json.dumps(str(certificates / "node-key.pem"))}
server.ssl.certificate: {json.dumps(str(certificates / "node.pem"))}
opensearch.hosts: [{json.dumps(url)}]
opensearch.username: {dashboard_user[0]}
opensearch.password: {json.dumps(dashboard_user[1])}
opensearch.ssl.verificationMode: full
opensearch.ssl.certificateAuthorities: [{json.dumps(str(ca))}]
opensearch.requestHeadersAllowlist: [securitytenant, Authorization]
opensearch_security.multitenancy.enabled: false
opensearch_security.auth.anonymous_auth_enabled: false
opensearch_security.cookie.secure: true
""",
            )
            interface = start(dashboard / "bin/wazuh-dashboard", visual, "dashboard")
            dashboard_url = f"https://localhost:{dashboard_port}"
            deadline = time.monotonic() + 150
            while True:
                assert interface.poll() is None, (
                    "Dashboard exited before authenticated startup"
                )
                try:
                    status, body = request(dashboard_url + "/api/status", ca, user)
                    if status == 200:
                        assert "status" in json.loads(body)
                        break
                except (OSError, urllib.error.URLError):
                    pass
                assert time.monotonic() < deadline, (
                    "Dashboard authenticated startup timed out"
                )
                time.sleep(1)
            assert request(
                dashboard_url + "/api/saved_objects/_find?type=index-pattern", ca
            )[0] in (401, 403)
            loaded_environment = dict(
                item.split(b"=", 1)
                for item in Path(f"/proc/{interface.pid}/environ")
                .read_bytes()
                .split(b"\0")
                if b"=" in item
            )
            assert b"NODE_TLS_REJECT_UNAUTHORIZED" not in loaded_environment
            assert b"NODE_OPTIONS" not in loaded_environment
            assert (
                loaded_environment[b"NODE_EXTRA_CA_CERTS"]
                == str(visual / "config/manager-ca.pem").encode()
            )
            assert (
                Path(f"/proc/{interface.pid}/exe").resolve()
                == (dashboard / "share/wazuh-dashboard/node/bin/node").resolve()
            ), "Dashboard loaded a different Node runtime"
            print("PASS dashboard authenticated startup and protected-resource refusal")
            print(
                "PASS actual Node runtime and sanitized private manager trust environment"
            )
            if integration:
                check_live_client(dashboard, integration, certificates / "wrong-ca.pem")
                status, body = request(
                    dashboard_url + "/api/check-stored-api",
                    ca,
                    user,
                    "POST",
                    {"id": "fixture"},
                    {"osd-xsrf": "true"},
                )
                assert status == 200, (
                    "Authenticated dashboard live manager API route failed"
                )
                reply = json.loads(body)
                assert reply.get("statusCode") == 200
                assert isinstance(reply.get("data"), dict)
                assert reply["data"].get("apiIsDown") is not True
                assert isinstance(reply["data"].get("cluster_info"), dict)
                assert reply["data"]["cluster_info"].get("manager"), (
                    "Dashboard did not return actual manager registry information"
                )
                print(
                    "PASS authenticated dashboard Wazuh route to still-running real manager API"
                )
        finally:
            for process in reversed(processes):
                if process.poll() is None:
                    os.killpg(process.pid, signal.SIGTERM)
                    try:
                        process.wait(timeout=15)
                    except subprocess.TimeoutExpired:
                        os.killpg(process.pid, signal.SIGKILL)
                        process.wait(timeout=10)
            for stream in streams:
                stream.close()
            # Retain the fixture's service logs only when an explicit private
            # evidence directory is supplied; never print credentials/configs.
            destination = os.environ.get("WAZUH_TEST_LOG_DIRECTORY")
            if destination:
                target = Path(destination).resolve(strict=True)
                assert target.is_dir() and target.stat().st_uid == os.getuid()
                assert not target.stat().st_mode & 0o077
                for log in [*root.glob("*.log"), *root.glob("*.trace")]:
                    with (target / log.name).open("xb") as output:
                        output.write(log.read_bytes())
                native_logs = root / "filebeat/logs"
                if native_logs.is_dir():
                    for log in native_logs.iterdir():
                        if log.is_file() and not log.is_symlink():
                            with (target / ("native-filebeat-" + log.name)).open(
                                "xb"
                            ) as output:
                                output.write(log.read_bytes())


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("indexer", type=Path)
    parser.add_argument("dashboard", type=Path)
    parser.add_argument("filebeat", type=Path)
    parser.add_argument("--runtime", action="store_true")
    parser.add_argument("--guard", type=Path)
    parser.add_argument("--alert-file", type=Path)
    parser.add_argument("--trace-filebeat", type=Path)
    parser.add_argument("--integration-config", type=Path)
    args = parser.parse_args()
    if args.guard:
        check_guard(args.guard)
        return
    check_layout(args.indexer, args.dashboard, args.filebeat)
    if args.runtime:
        integration = (
            integration_settings(args.integration_config)
            if args.integration_config
            else None
        )
        alert_file = Path(integration["alert_path"]) if integration else args.alert_file
        check_runtime(
            args.indexer,
            args.dashboard,
            args.filebeat,
            alert_file,
            args.trace_filebeat,
            integration,
        )


if __name__ == "__main__":
    main()
