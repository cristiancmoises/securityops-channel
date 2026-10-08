"""Exercise the installed desktop and SDK without cards or external services."""

import argparse
import base64
import contextlib
import http.client
import json
import os
import subprocess
import tempfile
import time
from pathlib import Path

from websockets.sync.client import connect


def output(arguments, environment):
    return subprocess.check_output(
        [str(item) for item in arguments],
        env=environment,
        text=True,
        stderr=subprocess.STDOUT,
        timeout=20,
    )


def loaded_qt(process, expected, state, label):
    maps = Path(f"/proc/{process.pid}/maps").read_text()
    libraries = sorted(
        {line.split()[-1] for line in maps.splitlines() if "-qtbase-" in line}
    )
    assert any("libQt6Core.so" in item for item in libraries), libraries
    assert any("libQt6Network.so" in item for item in libraries), libraries
    assert all(item.startswith(str(expected.resolve()) + "/") for item in libraries), (
        libraries
    )
    (state / f"{label}-qt-libraries.json").write_text(json.dumps(libraries, indent=2))
    print("PASS: actual", label, "loads only the pinned patched Qt base", expected)


def loaded_qt_leaves(process, expected_svg, expected_qml, state, label):
    maps = Path(f"/proc/{process.pid}/maps").read_text()
    evidence = {}
    for name, expected, required in (
        ("qtsvg", expected_svg, ("libQt6Svg.so",)),
        ("qtdeclarative", expected_qml, ("libQt6Qml.so", "libQt6Quick.so")),
    ):
        libraries = sorted(
            {line.split()[-1] for line in maps.splitlines() if "-" + name + "-" in line}
        )
        for library in required:
            assert any(library in item for item in libraries), (name, libraries)
        assert all(
            item.startswith(str(expected.resolve()) + "/") for item in libraries
        ), (name, libraries)
        evidence[name] = libraries
    (state / f"{label}-qt-leaves.json").write_text(json.dumps(evidence, indent=2))
    print("PASS: actual", label, "loads only the pinned SVG/QML pair")


@contextlib.contextmanager
def running(arguments, environment, logfile):
    with logfile.open("w") as stream:
        process = subprocess.Popen(
            [str(item) for item in arguments],
            env=environment,
            stdout=stream,
            stderr=subprocess.STDOUT,
        )
        try:
            yield process
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=10)


def sdk(process, state):
    portfile = state / f"AusweisApp.{process.pid}.port"
    deadline = time.monotonic() + 45
    while not portfile.exists():
        assert process.poll() is None, "SDK exited before readiness"
        assert time.monotonic() < deadline, "SDK port file was not created"
        time.sleep(0.1)
    port = int(portfile.read_text().strip())
    assert 0 < port <= 65535
    connection = http.client.HTTPConnection("127.0.0.1", port, timeout=5)
    try:
        connection.request("GET", "/eID-Client?Status=json")
        http_response = connection.getresponse()
        assert http_response.status == 200
        information = json.loads(http_response.read())
        assert information["Implementation-Version"] == "2.6.0"
    finally:
        connection.close()
    uri = f"ws://127.0.0.1:{port}/eID-Kernel"
    # Rejected upgrades use upstream's HTTP/1.0 error response, which the
    # websockets client rejects before exposing its status.  Inspect the real
    # upgrade response with an HTTP client rather than accepting any exception.
    connection = http.client.HTTPConnection("127.0.0.1", port, timeout=5)
    try:
        connection.request(
            "GET",
            "/eID-Kernel",
            headers={
                "Upgrade": "websocket",
                "Connection": "Upgrade",
                "Sec-WebSocket-Version": "13",
                "Sec-WebSocket-Key": base64.b64encode(os.urandom(16)).decode("ascii"),
                "Origin": "https://example.invalid",
            },
        )
        rejected = connection.getresponse()
        assert rejected.status == 403, rejected.status
        rejected.read()
    finally:
        connection.close()
    with connect(
        uri,
        user_agent_header="Local package acceptance",
        open_timeout=5,
        close_timeout=3,
        max_size=1048576,
    ) as websocket:

        def response(expected):
            deadline = time.monotonic() + 10
            while time.monotonic() < deadline:
                message = json.loads(websocket.recv(timeout=5))
                if message.get("msg") == expected:
                    return message
            raise AssertionError(f"SDK did not return {expected}")

        def command(name, expected, **parameters):
            websocket.send(json.dumps({"cmd": name, **parameters}))
            return response(expected)

        information = command("GET_INFO", "INFO")
        assert information["VersionInfo"]["Implementation-Version"] == "2.6.0"
        levels = command("GET_API_LEVEL", "API_LEVEL")
        assert levels["available"] == [1, 2, 3] and levels["current"] == 3
        invalid_level = command("SET_API_LEVEL", "API_LEVEL", level="invalid")
        assert invalid_level["error"] == "Invalid level"
        assert invalid_level["current"] == 3
        assert command("GET_API_LEVEL", "API_LEVEL")["current"] == 3
        readers = command("GET_READER_LIST", "READER_LIST")
        # SimulatorReaderManagerPlugin enables the built-in reader in SDK mode.
        # Require that exact cardless software reader, never a hardware reader.
        assert readers["readers"] == [
            {
                "attached": True,
                "card": None,
                "insertable": True,
                "keypad": True,
                "name": "Simulator",
            }
        ], readers
        status = command("GET_STATUS", "STATUS")
        assert status["workflow"] is None
        invalid = command("PACKAGE_TEST_UNKNOWN", "UNKNOWN_COMMAND")
        assert invalid["error"] == "PACKAGE_TEST_UNKNOWN"
        invalid_state = command("GET_CERTIFICATE", "BAD_STATE")
        assert invalid_state["error"] == "GET_CERTIFICATE"
        websocket.send("{")
        assert "offset:" in response("INVALID")["error"]
        assert (
            command("GET_INFO", "INFO")["VersionInfo"]["Implementation-Version"]
            == "2.6.0"
        )
    print("PASS: HTTP status, SDK commands, invalid input and origin refusal")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("desktop", type=Path)
    parser.add_argument("state", type=Path)
    parser.add_argument("--qtbase", type=Path, required=True)
    parser.add_argument("--qtsvg", type=Path, required=True)
    parser.add_argument("--qtdeclarative", type=Path, required=True)
    args = parser.parse_args()
    assert os.getuid() != 0
    assert {item.name for item in Path("/sys/class/net").iterdir()} == {"lo"}
    assert not Path("/run/pcscd").exists()
    assert str(args.desktop.resolve()).startswith("/gnu/store/")
    binary = args.desktop / "bin/AusweisApp"
    with tempfile.TemporaryDirectory(prefix="ausweisapp-", dir=args.state) as name:
        private = Path(name)
        environment = dict(os.environ)
        for variable in (
            "HOME",
            "TMPDIR",
            "XDG_CONFIG_HOME",
            "XDG_DATA_HOME",
            "XDG_CACHE_HOME",
            "XDG_RUNTIME_DIR",
        ):
            directory = private / variable.lower()
            directory.mkdir(mode=0o700)
            environment[variable] = str(directory)
        environment.update(QT_QPA_PLATFORM="offscreen", LANG="C.UTF-8")
        environment.pop("AUSWEISAPP_WEBSOCKET_ORIGIN", None)
        environment.pop("QT_SVG_DEFAULT_OPTIONS", None)
        version = output([binary, "--version"], environment).strip()
        print("Installed command-line version:", version)
        assert version == "AusweisApp 2.6.0", version
        with running(
            [
                binary,
                "--ui",
                "websocket",
                "--ui",
                "webservice",
                "--address",
                "127.0.0.1",
                "--port",
                "0",
                "--no-logfile",
                "--no-proxy",
            ],
            environment,
            args.state / "sdk.log",
        ) as process:
            sdk(process, Path(environment["TMPDIR"]))
            maps = Path(f"/proc/{process.pid}/maps").read_text()
            for library in ("openssl-3.5.9", "llhttp-9.4.3", "qtbase-6.9.2"):
                assert library in maps, library
            loaded_qt(process, args.qtbase, args.state, "sdk")
            loaded_qt_leaves(process, args.qtsvg, args.qtdeclarative, args.state, "sdk")
        display_log = args.state / "xvfb.log"
        with running(
            [
                "Xvfb",
                "-displayfd",
                "1",
                "-screen",
                "0",
                "1280x900x24",
                "-nolisten",
                "tcp",
            ],
            environment,
            display_log,
        ) as xvfb:
            deadline = time.monotonic() + 15
            while True:
                assert xvfb.poll() is None, "private display exited early"
                numbers = [
                    line
                    for line in display_log.read_text().splitlines()
                    if line.isdigit()
                ]
                if numbers:
                    break
                assert time.monotonic() < deadline, "private display did not start"
                time.sleep(0.1)
            environment.update(
                DISPLAY=":" + numbers[0],
                QT_QPA_PLATFORM="xcb",
                QT_QUICK_BACKEND="software",
            )
            with running(
                [
                    binary,
                    "--show",
                    "--address",
                    "127.0.0.1",
                    "--port",
                    "0",
                    "--no-logfile",
                    "--no-proxy",
                ],
                environment,
                args.state / "desktop.log",
            ) as desktop:
                deadline = time.monotonic() + 45
                while True:
                    assert desktop.poll() is None, "desktop exited early"
                    windows = output(["xwininfo", "-root", "-tree"], environment)
                    if '"AusweisApp' in windows:
                        break
                    assert time.monotonic() < deadline, "desktop did not render"
                    time.sleep(0.2)
                time.sleep(3)
                loaded_qt(desktop, args.qtbase, args.state, "desktop")
                loaded_qt_leaves(
                    desktop, args.qtsvg, args.qtdeclarative, args.state, "desktop"
                )
                output(
                    ["import", "-window", "root", args.state / "desktop.png"],
                    environment,
                )
                print("PASS: visible installed desktop; screenshot requires inspection")
    print("Card authentication, PIN entry and external providers were not tested")


if __name__ == "__main__":
    main()
