"""Check current upstream C/Python installation-root definitions directly.

Usage: python3 tests/wazuh-layout.py PINNED_SOURCE_DIRECTORY
This tests the relocation definitions, not a built agent or manager.
"""

import argparse
import ast
import hashlib
import importlib.util
import json
import os
import re
import secrets
import shutil
import sqlite3
import subprocess
import sys
import tempfile
from pathlib import Path


def native_definition(source):
    text = (source / "src/shared/file_op.c").read_text()
    start = text.index("char *w_homedir(char *arg) {")
    depth = 0
    for offset, character in enumerate(text[start:]):
        if character == "{":
            depth += 1
        elif character == "}":
            depth -= 1
            if depth == 0:
                helpers = text.find("int w_safe_path_ancestry(")
                prefix = text[helpers:start] if 0 <= helpers < start else ""
                return prefix + text[start : start + offset + 1]
    raise ValueError("incomplete native installation-root definition")


def python_definition(source, immutable):
    text = (source / "framework/wazuh/core/common.py").read_text()
    function = next(
        node
        for node in ast.parse(text).body
        if isinstance(node, ast.FunctionDef) and node.name == "find_wazuh_path"
    )
    function.decorator_list = []
    return (
        "import os\n"
        f"__file__ = {str(immutable / 'framework/wazuh/core/common.py')!r}\n"
        + ast.unparse(function)
        + "\nprint(find_wazuh_path())\n"
    )


def bootstrap_definition(source, security):
    tree = ast.parse((source / "framework/wazuh/rbac/orm.py").read_text())
    assert any(
        isinstance(node, ast.Import)
        and any(alias.name == "stat" for alias in node.names)
        for node in tree.body
    ), "the installed RBAC module must import its ownership-check dependency"
    function = next(
        node
        for node in tree.body
        if isinstance(node, ast.FunctionDef) and node.name == "load_initial_users"
    )
    return (
        "import os, stat, json\nfrom types import SimpleNamespace\n"
        "yaml = SimpleNamespace(safe_load=lambda stream: json.load(stream))\n"
        f"SECURITY_PATH = {str(security)!r}\n"
        + ast.unparse(function)
        + "\nload_initial_users()\nprint('accepted private bootstrap')\n"
    )


def retained_mitre_license(package):
    licenses = list((package / "share/wazuh/licenses/mitre").glob("*LICENSE.txt"))
    assert len(licenses) == 1, "exact MITRE license asset must be retained"
    assert (
        hashlib.sha256(licenses[0].read_bytes()).hexdigest()
        == "738144f7fb054722a4ef9d3367c51710341dc12fc574c6ac3a41daaaecd8bf5e"
    )


def python_implementation_layout(package):
    """Python implementations are data; only pinned launchers are executable."""
    helpers = package / "libexec/wazuh"
    violations = []
    for directory in ("scripts", "wodles", "active-response", "integrations"):
        for implementation in (helpers / directory).rglob("*.py"):
            first_line = implementation.read_bytes().split(b"\n", 1)[0]
            if first_line.startswith(b"#!"):
                violations.append(f"implementation shebang: {implementation}")
            if implementation.stat().st_mode & 0o111:
                violations.append(f"executable implementation: {implementation}")
    for installed in package.rglob("*"):
        if (
            installed.is_file()
            and not installed.is_symlink()
            and b"-python-3.12" in installed.read_bytes()
        ):
            violations.append(f"unintended build interpreter: {installed}")
    developer_tests = package / "share/wazuh/ruleset/testing"
    if developer_tests.exists():
        violations.append(f"unsupported upstream developer fixture: {developer_tests}")
    assert not violations, "\n".join(violations)
    assert (helpers / "python").is_symlink(), "retain the exact shared runtime"
    for relative in (
        "wodles/aws/aws-s3",
        "wodles/gcloud/gcloud",
        "wodles/azure/azure-logs",
        "wodles/docker/DockerListener",
        "active-response/bin/kaspersky-helper",
    ):
        wrapper = helpers / relative
        assert wrapper.stat().st_mode & 0o111, wrapper
        assert "/bin/python3 -I -B" in wrapper.read_text(), wrapper
    if (helpers / "scripts").exists():
        for command, implementation in (
            ("wazuh-apid", "wazuh_apid.py"),
            ("agent-groups", "agent_groups.py"),
            ("agent-upgrade", "agent_upgrade.py"),
        ):
            wrapper = package / "bin" / command
            assert wrapper.stat().st_mode & 0o111, wrapper
            assert f"/bin/python3 -I -B {helpers}/scripts/{implementation}" in (
                wrapper.read_text()
            ), wrapper
    print("PASS: implementation-only Python sources and pinned canonical launchers")


def default_asset_layout(package):
    """Require actual immutable default tools and a queryable shipped database."""
    helpers = package / "libexec/wazuh"
    retained_mitre_license(package)
    for relative in (
        "wodles/aws/aws-s3",
        "wodles/gcloud/gcloud",
        "wodles/azure/azure-logs",
        "wodles/docker/DockerListener",
        "integrations/slack",
        "integrations/pagerduty",
        "integrations/virustotal",
        "integrations/shuffle",
        "integrations/maltiverse",
        "agentless/register_host.sh",
        "agentless/ssh_integrity_check_linux",
        "active-response/bin/restart.sh",
        "active-response/bin/firewall-drop",
        "active-response/bin/kaspersky",
        "active-response/bin/kaspersky-helper",
    ):
        executable = helpers / relative
        assert executable.is_file() and os.access(executable, os.X_OK), relative
        assert str(executable.resolve()).startswith("/gnu/store/"), executable
    database = package / "share/wazuh/var/db/mitre.db"
    with sqlite3.connect(f"file:{database}?mode=ro", uri=True) as connection:
        assert connection.execute("PRAGMA integrity_check").fetchone() == ("ok",)
        assert connection.execute("SELECT COUNT(*) FROM technique").fetchone()[0] > 100
        assert connection.execute("SELECT COUNT(*) FROM use").fetchone()[0] > 100
        assert connection.execute("SELECT COUNT(*) FROM metadata").fetchone()[0] > 0
    print("PASS: immutable default manager assets and real MITRE SQLite data")


def default_asset_runtime(package, state, *, server=True):
    """Exercise actual helper imports/errors without contacting providers."""
    helpers = package / "libexec/wazuh"
    retained_mitre_license(package)
    environment = {**os.environ, "WAZUH_HOME": str(state), "PATH": "/nonexistent"}
    for relative in (
        "var/wodles/aws",
        "var/wodles/azure",
        "var/wodles/gcloud",
        "var/active-response",
        "logs",
        "agentless",
    ):
        (state / relative).mkdir(parents=True, exist_ok=True)
    for relative in (
        "wodles/aws/aws-s3",
        "wodles/gcloud/gcloud",
        "wodles/azure/azure-logs",
        "active-response/bin/kaspersky-helper",
        "active-response/bin/restart.sh",
    ):
        result = subprocess.run(
            [str(helpers / relative), "--help" if "restart" not in relative else "-h"],
            env=environment,
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
        assert result.returncode == 0, (relative, result.stdout, result.stderr)
        assert "usage" in (result.stdout + result.stderr).lower(), relative
        print(f"PASS: native helper dependency/argument handling: {relative}")
    for value in ("/", "/gnu/store", "relative-state"):
        result = subprocess.run(
            [str(helpers / "wodles/aws/aws-s3"), "--help"],
            env={**environment, "WAZUH_HOME": value},
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
        assert result.returncode != 0, value
    print("PASS: helper bootstrap refuses unsafe state before provider handling")
    for name in ("firewall-drop", "host-deny", "disable-account", "kaspersky"):
        result = subprocess.run(
            [str(helpers / "active-response/bin" / name)],
            input=(
                '{"version":1,"origin":{"name":"fixture","module":"fixture"},'
                '"command":"fixture-invalid","parameters":{}}\n'
            ),
            env=environment,
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
        assert result.returncode == 255, (name, result.stdout, result.stderr)
    assert (
        "Invalid value of 'command'"
        in (state / "logs/active-responses.log").read_text()
    )
    print("PASS: native AR adapters reject invalid protocol before any host action")
    python = helpers / "python/bin/python3"
    result = subprocess.run(
        [
            str(python),
            "-I",
            "-B",
            "-c",
            (
                "import sys,json; "
                "from pathlib import Path; "
                "sys.path[:0]=[sys.argv[1]+'/wodles/docker',sys.argv[1]+'/wodles']; "
                "from DockerListener import DockerListener; listener=DockerListener(); "
                "assert listener.wazuh_path==sys.argv[2]; "
                'assert listener.format_msg(\'{"Action":"fixture"}\')=='
                "{'integration':'docker','docker':{'Action':'fixture'}}; "
                "sys.path[:0]=[sys.argv[1]+'/wodles/azure']; "
                "from db import orm; assert orm.check_database_integrity(); "
                "assert Path(orm.database_path).parent==Path(sys.argv[2])/'var/wodles/azure'; "
                "assert orm.session.execute(orm.select(orm.Storage)).all()==[]"
            ),
            str(helpers),
            str(state),
        ],
        env=environment,
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    assert result.returncode == 0, result.stderr
    assert (state / "var/wodles/azure/azure.db").is_file()
    print("PASS: actual Docker transformation and mutable Azure SQLite operations")
    if not server:
        assert not (helpers / "integrations").exists()
        assert not (helpers / "agentless").exists()
        print("PASS: endpoint role does not install manager-only remote helpers")
        return
    for name in ("slack", "pagerduty", "virustotal", "shuffle", "maltiverse"):
        result = subprocess.run(
            [str(helpers / "integrations" / name)],
            env=environment,
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
        assert result.returncode == 2, (name, result.stdout, result.stderr)
        assert (state / "logs/integrations.log").is_file()
        print(
            f"PASS: integration refuses missing input without provider contact: {name}"
        )
    (state / "agentless/register_host.sh").symlink_to(
        helpers / "agentless/register_host.sh"
    )
    for script, arguments in (
        ("register_host.sh", ("-h",)),
        ("ssh_integrity_check_linux", ("test", "test")),
    ):
        result = subprocess.run(
            [str(helpers / "agentless" / script), *arguments],
            env=environment,
            cwd=state,
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
        assert result.returncode == 0, (script, result.stdout, result.stderr)
    assert not (state / "agentless/.passlist").exists()
    print("PASS: agentless help/Expect test mode without credentials or SSH")


def fork_tracking(fixture, state):
    """Check ownership and bounded pidfd cleanup with a harmless local child."""
    specification = importlib.util.spec_from_file_location("core_fixture", fixture)
    assert specification is not None and specification.loader is not None
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    (state / "var/run").mkdir(parents=True)
    launcher = subprocess.Popen(
        [
            sys.executable,
            "-c",
            (
                "import os, sys, time; from pathlib import Path; "
                "child=os.fork(); "
                "os._exit(0) if child else None; "
                "record=Path(sys.argv[1])/'var/run'/f'fixture-daemon-{os.getpid()}.pid'; "
                "record.write_text(str(os.getpid())+'\\n'); record.chmod(0o640); "
                "time.sleep(30)"
            ),
            str(state),
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    owned = module.follow_forked_daemon(
        launcher,
        state,
        "fixture-daemon",
        Path(sys.executable),
        Path("/"),
        os.getuid(),
    )
    try:
        assert owned.poll() is None
        try:
            module.follow_forked_daemon(
                launcher,
                state,
                "fixture-daemon",
                Path("/gnu/store/not-the-owned-executable"),
                Path("/"),
                os.getuid(),
            )
        except AssertionError:
            pass
        else:
            raise AssertionError("accepted an unexpected child executable")
        owned.terminate()
        owned.wait(timeout=5)
        assert owned.poll() is not None
        print("PASS: owned fork identity, liveness, rejection and pidfd cleanup")
    finally:
        module.stop(owned)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("--agent", type=Path)
    parser.add_argument("--manager", type=Path)
    parser.add_argument("--assets", action="store_true")
    parser.add_argument("--process-fixture", type=Path)
    parser.add_argument("--implementations", action="store_true")
    parser.add_argument("--store-references", type=Path)
    arguments = parser.parse_args()
    if arguments.assets and not arguments.manager:
        parser.error("--assets requires a manager package")
    if arguments.implementations:
        packages = [
            package for package in (arguments.manager, arguments.agent) if package
        ]
        if not packages:
            parser.error("--implementations requires a manager or agent package")
        for package in packages:
            python_implementation_layout(package)
        if arguments.store_references:
            references = arguments.store_references.read_text()
            for package in packages:
                assert str(package) in references, (
                    "check references of these exact outputs"
                )
            assert "-python-3.12" not in references, (
                "unintended build interpreter closure"
            )
    if arguments.assets:
        default_asset_layout(arguments.manager)
    source = arguments.source
    with tempfile.TemporaryDirectory(prefix="securityops-wazuh-layout-") as temporary:
        state = Path(temporary)
        immutable = state / "immutable"
        binary_dir = immutable / "bin"
        binary_dir.mkdir(parents=True)
        mutable = state / "mutable"
        mutable.mkdir()
        if arguments.process_fixture:
            fork_tracking(arguments.process_fixture, state / "owned-process")
        unsafe = state / "world-writable"
        unsafe.mkdir()
        unsafe.chmod(0o777)
        group_writable = state / "group-writable"
        group_writable.mkdir()
        group_writable.chmod(0o770)
        unsafe_ancestor = state / "unsafe-ancestor"
        unsafe_ancestor.mkdir()
        unsafe_ancestor.chmod(0o770)
        descendant = unsafe_ancestor / "private-state"
        descendant.mkdir(mode=0o700)
        unsafe_alias = unsafe_ancestor / "alias"
        unsafe_alias.symlink_to(mutable)
        sticky_state = state / "sticky-state"
        sticky_state.mkdir()
        sticky_state.chmod(0o1777)
        spaced = state / "space state"
        spaced.mkdir(mode=0o700)
        spaced_alias = state / "space-alias"
        spaced_alias.symlink_to(spaced)
        globbed = state / "glob[state]"
        globbed.mkdir(mode=0o700)
        unicode_state = state / "unicode-é"
        unicode_state.mkdir(mode=0o700)
        newline_state = state / "newline\n"
        newline_state.mkdir(mode=0o700)
        newline_alias = state / "newline-alias"
        newline_alias.symlink_to(newline_state)
        alias = state / "mutable-link"
        alias.symlink_to(mutable)
        translation = state / "fixture.c"
        translation.write_text(
            "#include <stdio.h>\n#include <stdlib.h>\n#include <string.h>\n"
            "#include <limits.h>\n#include <unistd.h>\n#include <libgen.h>\n"
            "#include <sys/stat.h>\n"
            '#define WAZUH_HOME_ENV "WAZUH_HOME"\n'
            '#define HOME_ERROR "invalid installation root"\n'
            "#define os_calloc(n, size, pointer) ((pointer) = calloc((n), (size)))\n"
            "#define os_free(pointer) free(pointer)\n#define w_stat stat\n"
            "#define merror_exit(...) exit(2)\n"
            "static char *w_strtok_r_str_delim(char *delimiter, char **value) {\n"
            "char *position = strstr(*value, delimiter);\n"
            "if (position) { *position = 0; }\nreturn *value; }\n"
            + native_definition(source)
            + "\nint main(int argc, char **argv) {\n"
            "(void)argc; char *root = w_homedir(argv[0]);\n"
            "puts(root); free(root); return 0; }\n"
        )
        executable = binary_dir / "fixture"
        subprocess.run(
            [
                "cc",
                "-std=gnu99",
                "-Wall",
                "-Wextra",
                str(translation),
                "-o",
                str(executable),
            ],
            check=True,
        )
        python_fixture = state / "python-fixture.py"
        python_fixture.write_text(python_definition(source, immutable))
        previous = os.environ.pop("WAZUH_HOME", None)
        try:
            for value, expected in (
                (None, immutable),
                ("", immutable),
                (str(mutable), mutable),
                (str(alias), mutable),
                ("relative-state", None),
                (str(state / "missing"), None),
                ("/", None),
                ("/gnu/store", None),
                (str(unsafe), None),
                (str(group_writable), None),
                (str(descendant), None),
                (str(unsafe_alias), None),
                (str(unsafe_ancestor / ".." / "mutable"), None),
                (str(sticky_state), None),
                (str(spaced), spaced),
                (str(spaced_alias), spaced),
                (str(globbed), globbed),
                (str(unicode_state), unicode_state),
                (str(newline_state), newline_state),
                (str(newline_alias), newline_state),
                ("//" + str(mutable).lstrip("/"), mutable),
            ):
                environment = os.environ.copy()
                if value is None:
                    os.environ.pop("WAZUH_HOME", None)
                else:
                    os.environ["WAZUH_HOME"] = value
                    environment["WAZUH_HOME"] = value
                native = subprocess.run(
                    [str(executable)],
                    env=environment,
                    text=True,
                    capture_output=True,
                    check=False,
                )
                python = subprocess.run(
                    [sys.executable, str(python_fixture)],
                    env=environment,
                    text=True,
                    capture_output=True,
                    check=False,
                )
                if expected is None:
                    assert native.returncode == 2, (value, native.stdout, native.stderr)
                    assert python.returncode != 0 and "ValueError" in python.stderr, (
                        value,
                        python.stdout,
                        python.stderr,
                    )
                else:
                    assert native.returncode == 0
                    assert native.stdout.removesuffix("\n") == str(expected)
                    assert python.returncode == 0
                    assert python.stdout.removesuffix("\n") == str(expected)
                print(f"PASS: C/Python relocation agrees for {value!r}")
        finally:
            if previous is None:
                os.environ.pop("WAZUH_HOME", None)
            else:
                os.environ["WAZUH_HOME"] = previous
        code_translation = state / "code-metadata.c"
        code_translation.write_text(
            translation.read_text().split("\nint main(int argc, char **argv) {")[0]
            + "\nint main(int argc, char **argv) {\n"
            "if (argc != 4) return 3;\n"
            "int directory = atoi(argv[2]);\n"
            'int safe = strcmp(argv[3], "root") == 0\n'
            "  ? w_safe_code_path(argv[1], directory)\n"
            "  : w_safe_path_ancestry(argv[1], geteuid(), directory);\n"
            "return safe ? 0 : 2; }\n"
        )
        code_probe = state / "code-metadata"
        subprocess.run(
            [
                "cc",
                "-std=gnu99",
                "-Wall",
                "-Wextra",
                str(code_translation),
                "-o",
                str(code_probe),
            ],
            check=True,
        )
        code_file = mutable / "admin-tool"
        code_file.write_text("metadata only; never executed\n")
        code_file.chmod(0o500)
        compiler = shutil.which("cc")
        assert compiler is not None
        # Guix's unprivileged container maps host store/root owners to another
        # UID.  Those paths must be refused by a root-only code policy there;
        # a non-container metadata-only run exercises the real root owners.
        root_owned_compiler = (
            Path(compiler).resolve().stat().st_uid == 0 and Path("/").stat().st_uid == 0
        )
        for path, directory, owner, accepted in (
            (code_file, 0, "caller", True),
            (mutable, 1, "caller", True),
            (group_writable, 1, "caller", False),
            (descendant, 1, "caller", False),
            (unsafe_alias, 1, "caller", False),
            (code_file, 0, "root", os.geteuid() == 0),
            (Path(compiler).resolve(), 0, "root", root_owned_compiler),
        ):
            result = subprocess.run(
                [str(code_probe), str(path), str(directory), owner],
                capture_output=True,
                text=True,
                timeout=15,
                check=False,
            )
            assert (result.returncode == 0) == accepted, (path, result.stderr)
        for package in (arguments.manager, arguments.agent):
            if package:
                result = subprocess.run(
                    [str(code_probe), str(package / "bin/wazuh-execd"), "0", "root"],
                    capture_output=True,
                    text=True,
                    timeout=15,
                    check=False,
                )
                expected_root_code = (
                    package / "bin/wazuh-execd"
                ).stat().st_uid == 0 and Path("/").stat().st_uid == 0
                assert (result.returncode == 0) == expected_root_code, result.stderr
        execd_source = (source / "src/os_execd/main.c").read_text()
        assert (
            execd_source.index("w_safe_code_path(AR_BINDIR, 1)")
            < execd_source.index("while ((c = getopt")
            < execd_source.index("ExecdConfig(cfg)")
        )
        exec_source = (source / "src/os_execd/exec.c").read_text()
        assert exec_source.index(
            "w_safe_code_path(exec_cmd[exec_size], 0)"
        ) < exec_source.index('process_file = wfopen(exec_cmd[exec_size], "r")')
        # Check the actual execution boundaries too: custom commands bypass
        # ReadExecConfig, while timeout/shutdown reuse earlier command paths.
        execution = (source / "src/os_execd/execd.c").read_text()
        opener = execution.split("static wfd_t *ExecdOpenCommand(", 1)[1].split(
            "int repeated_offenders_timeout", 1
        )[0]
        assert (
            opener.index("geteuid() == 0")
            < opener.index("w_safe_code_path(path, 0)")
            < opener.index("return NULL;")
            < opener.index("return wpopenv(path, argv, flags);")
        )
        assert execution.count("wpopenv(") == 1, "all three AR paths use the guard"
        assert execution.count("= ExecdOpenCommand(") == 3
        direct = exec_source.split("void ExecCmd(char *const *cmd)", 1)[1].split(
            "void ExecCmd_Win32", 1
        )[0]
        assert (
            direct.index("geteuid() == 0")
            < direct.index("w_safe_code_path(*cmd, 0)")
            < direct.index("return;")
            < direct.index("pid = fork();")
            < direct.index("execv(*cmd, cmd)")
        )
        communication = (source / "src/os_execd/wcom.c").read_text()
        for name in ("restart", "reload"):
            command = communication.split(f"size_t wcom_{name}(", 1)[1].split(
                "\nsize_t ", 1
            )[0]
            assert (
                command.index("geteuid() == 0")
                < command.index("w_safe_code_path(exec_cmd[0], 0)")
                < command.index("return strlen(*output);")
                < command.index("switch (fork())")
                < command.index("execv(exec_cmd[0], exec_cmd)")
            )
        # Execute the exact two sink definitions with real metadata policy.
        # Only UID selection and process-opening boundaries are simulated:
        # counters never fork, exec, open a process, or run an AR command.
        sink_translation = state / "sink-metadata.c"
        sink_translation.write_text(
            translation.read_text().split("\nint main(", 1)[0]
            + "\n#include <errno.h>\n#include <assert.h>\n"
            "typedef struct { int marker; } wfd_t;\n"
            "static wfd_t descriptor;\n"
            "static int opened, forked, executed, observed_flags;\n"
            "static uid_t selected_uid;\n"
            "#define geteuid() selected_uid\n"
            "#define merror(...) ((void)0)\n"
            "static wfd_t *wpopenv(const char *path, char *const *argv, int flags) {\n"
            "assert(path == argv[0]); opened++; observed_flags = flags;\n"
            "return &descriptor; }\n"
            "static pid_t fixture_fork(void) { forked++; return -1; }\n"
            "static int fixture_execv(const char *path, char *const *argv) {\n"
            "(void)path; (void)argv; executed++; return -1; }\n"
            "#define fork fixture_fork\n#define execv fixture_execv\n"
            + "static wfd_t *ExecdOpenCommand("
            + opener
            + "void ExecCmd(char *const *cmd)"
            + direct.split("\n}\n", 1)[0]
            + "\n}\nint main(int argc, char **argv) {\n"
            "if (argc != 4) return 3;\n"
            "selected_uid = atoi(argv[3]); int accepted = atoi(argv[2]);\n"
            "char *command[] = {argv[1], NULL};\n"
            "wfd_t *result = ExecdOpenCommand(command[0], command, 7);\n"
            "assert(opened == accepted);\n"
            "if (accepted) { assert(result == &descriptor && observed_flags == 7); }\n"
            "else { assert(result == NULL && errno == EPERM); }\n"
            "ExecCmd(command); assert(forked == accepted); assert(executed == 0);\n"
            "return 0; }\n"
        )
        sink_probe = state / "sink-metadata"
        subprocess.run(
            [
                "cc",
                "-std=gnu99",
                "-Wall",
                "-Wextra",
                str(sink_translation),
                "-o",
                str(sink_probe),
            ],
            check=True,
        )
        for path, accepted, simulated_uid in (
            (code_file, os.geteuid() == 0, 0),
            (Path(compiler).resolve(), root_owned_compiler, 0),
            (code_file, True, 1001),
        ):
            result = subprocess.run(
                [str(sink_probe), str(path), str(int(accepted)), str(simulated_uid)],
                capture_output=True,
                text=True,
                timeout=15,
                check=False,
            )
            assert result.returncode == 0, (path, simulated_uid, result.stderr)
        print(
            "PASS: exact sink decisions with real metadata; UID/boundaries simulated, no actions"
        )
        print(
            "PASS: exact native code metadata policy before reads and all execution sinks"
        )
        security = state / "security"
        security.mkdir(mode=0o700)
        bootstrap = security / "initial-users.yaml"
        bootstrap_fixture = state / "bootstrap-fixture.py"
        bootstrap_fixture.write_text(bootstrap_definition(source, security))
        private_users = {
            "default_users": {
                name: {"password": secrets.token_hex(32), "allow_run_as": False}
                for name in ("wazuh", "wazuh-wui")
            }
        }
        weak_users = json.loads(json.dumps(private_users))
        weak_users["default_users"]["wazuh"]["password"] = "wazuh"
        for mode, content, accepted in (
            (None, None, False),
            (0o600, private_users, True),
            (0o644, private_users, False),
            (0o666, private_users, False),
            (0o600, weak_users, False),
            (0o600, {}, False),
        ):
            if mode is not None:
                bootstrap.write_text(json.dumps(content))
                bootstrap.chmod(mode)
            result = subprocess.run(
                [sys.executable, str(bootstrap_fixture)],
                capture_output=True,
                text=True,
                timeout=15,
                check=False,
            )
            assert (result.returncode == 0) == accepted
            if content == weak_users:
                assert "explicit passwords" in result.stderr
            print(f"PASS: private API bootstrap accepted={accepted}, mode={mode!r}")
        bootstrap.unlink()
        bootstrap.symlink_to(python_fixture)
        result = subprocess.run(
            [sys.executable, str(bootstrap_fixture)],
            capture_output=True,
            text=True,
            timeout=15,
            check=False,
        )
        assert result.returncode != 0
        print("PASS: private API bootstrap refuses a symlink")
        if arguments.agent:
            for configured in (
                mutable,
                unsafe,
                group_writable,
                descendant,
                sticky_state,
                spaced,
                globbed,
                unicode_state,
                newline_state,
            ):
                (configured / "etc").mkdir()
                (configured / "etc/ossec.conf").write_text(
                    "<ossec_config></ossec_config>\n"
                )
                shutil.copyfile(
                    source / "etc/internal_options.conf",
                    configured / "etc/internal_options.conf",
                )
            for value, accepted in (
                (str(mutable), True),
                (str(alias), True),
                ("relative-state", False),
                (str(state / "missing"), False),
                ("/", False),
                ("/gnu/store", False),
                (str(unsafe), False),
                (str(group_writable), False),
                (str(descendant), False),
                (str(unsafe_alias), False),
                (str(unsafe_ancestor / ".." / "mutable"), False),
                (str(sticky_state), False),
                (str(spaced), True),
                (str(spaced_alias), True),
                (str(globbed), True),
                (str(unicode_state), True),
                (str(newline_state), True),
                (str(newline_alias), True),
            ):
                result = subprocess.run(
                    [str(arguments.agent / "bin/wazuh-agentd"), "-V"],
                    env={**os.environ, "WAZUH_HOME": value},
                    # Early upstream logging reads cwd/etc before chdir.
                    # Keep that configuration valid so the guard's own
                    # diagnostic, not a missing XML file, proves refusal.
                    cwd=mutable,
                    capture_output=True,
                    text=True,
                    timeout=15,
                    check=False,
                )
                if accepted:
                    assert result.returncode == 0, result.stderr
                    assert "4.14.8" in result.stdout + result.stderr
                else:
                    assert result.returncode != 0, value
                    assert "Unsafe WAZUH_HOME state ownership or ancestry" in (
                        result.stderr
                    ), (value, result.stdout, result.stderr)
                print(f"PASS: compiled agent root validation for {value!r}")
                control = subprocess.run(
                    [str(arguments.agent / "bin/wazuh-control"), "info"],
                    env={**os.environ, "WAZUH_HOME": value},
                    cwd=mutable,
                    capture_output=True,
                    text=True,
                    timeout=15,
                    check=False,
                )
                control_accepted = (
                    accepted
                    and re.fullmatch(r"/[A-Za-z0-9_./-]*", value) is not None
                    and re.fullmatch(r"/[A-Za-z0-9_./-]*", str(Path(value).resolve()))
                    is not None
                )
                assert (control.returncode == 0) == control_accepted
                if control_accepted:
                    assert 'WAZUH_TYPE="agent"' in control.stdout
                print(f"PASS: immutable control-script root validation for {value!r}")
        if arguments.manager:
            run = mutable / "var/run"
            run.mkdir(parents=True)
            (mutable / "bin").symlink_to(arguments.manager / "bin")
            control = arguments.manager / "bin/wazuh-control"
            settings = run / ".process_list"
            for action, expected in (
                ("enable", 'DEBUG_CLI="-d"'),
                ("disable", 'DEBUG_CLI=""'),
            ):
                result = subprocess.run(
                    [str(control), action, "debug"],
                    env={**os.environ, "WAZUH_HOME": str(mutable)},
                    capture_output=True,
                    text=True,
                    timeout=15,
                    check=False,
                )
                assert result.returncode == 0, result.stderr
                assert settings.read_text().splitlines()[-1] == expected
            settings.write_text('DEBUG_CLI="unsupported-setting"\n')
            result = subprocess.run(
                [str(control), "info"],
                env={**os.environ, "WAZUH_HOME": str(mutable)},
                capture_output=True,
                text=True,
                timeout=15,
                check=False,
            )
            assert result.returncode != 0
            print(
                "PASS: manager debug control uses mutable data and rejects unsupported records"
            )
            private_security = mutable / "api/configuration/security"
            private_security.mkdir(parents=True, mode=0o700)
            private_users = private_security / "initial-users.yaml"
            private_users.write_text(
                json.dumps(
                    {
                        "default_users": {
                            username: {
                                "password": secrets.token_urlsafe(32),
                                "allow_run_as": username == "wazuh-wui",
                            }
                            for username in ("wazuh-wui", "wazuh")
                        }
                    }
                )
            )
            private_users.chmod(0o600)
            result = subprocess.run(
                [
                    str(arguments.manager / "libexec/wazuh/python/bin/python3"),
                    "-I",
                    "-B",
                    "-c",
                    (
                        "from wazuh.rbac import orm; users = orm.load_initial_users(); "
                        "assert tuple(users['default_users']) == ('wazuh', 'wazuh-wui')"
                    ),
                ],
                env={**os.environ, "WAZUH_HOME": str(mutable)},
                capture_output=True,
                text=True,
                timeout=30,
                check=False,
            )
            assert result.returncode == 0, result.stderr
            print("PASS: actual installed native RBAC module loads private users")
            if arguments.assets:
                default_asset_runtime(arguments.manager, mutable)
                if arguments.agent:
                    default_asset_runtime(
                        arguments.agent, state / "agent-default-assets", server=False
                    )


if __name__ == "__main__":
    main()
