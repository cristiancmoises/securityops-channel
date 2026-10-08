#!/usr/bin/env python3
"""Check an installed LibreWolf in a private loopback-only Guix container."""

import argparse
import base64
import ctypes
import http.server
import json
import os
import re
import socket
import subprocess
import tempfile
import threading
import time
from pathlib import Path

PAGE = b"""<!doctype html><title>LibreWolf fixture</title>
<h1>LibreWolf fixture</h1><output id="result">pending</output>
<canvas id="canvas" width="32" height="32"></canvas><script>
const ctx = document.getElementById('canvas').getContext('2d');
ctx.fillStyle = '#123456'; ctx.fillRect(0, 0, 32, 32);
const correct = Math.sqrt(1764) === 42 && 123456789n * 9n === 1111111101n;
const result = document.getElementById('result');
result.dataset.result = correct ? 'pass' : 'fail';
result.textContent = 'JavaScript arithmetic: ' + result.dataset.result;
</script>"""


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(PAGE)))
        self.end_headers()
        self.wfile.write(PAGE)

    def log_message(self, format: str, *args: object) -> None:
        pass


class Marionette:
    def __init__(self, connection):
        self.connection = connection
        self.stream = connection.makefile("rb")
        self.identifier = 0
        assert self.receive()["marionetteProtocol"] == 3

    def receive(self):
        length = bytearray()
        while True:
            character = self.stream.read(1)
            if character == b":":
                break
            assert character.isdigit() and len(length) < 9, "invalid frame length"
            length.extend(character)
        size = int(length)
        assert 0 < size <= 16 * 1024 * 1024, "oversized frame"
        payload = self.stream.read(size)
        assert len(payload) == size, "truncated frame"
        return json.loads(payload)

    def command(self, name, parameters):
        self.identifier += 1
        payload = json.dumps([0, self.identifier, name, parameters]).encode()
        self.connection.sendall(str(len(payload)).encode() + b":" + payload)
        response = self.receive()
        assert response[:2] == [1, self.identifier], response
        assert response[2] is None, response[2]
        return response[3]

    def script(self, script):
        return self.command(
            "WebDriver:ExecuteScript",
            {
                "script": script,
                "args": [],
                "newSandbox": True,
                "sandbox": "default",
                "line": 1,
                "filename": "fixture",
            },
        )["value"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("browser", type=Path)
    parser.add_argument("version")
    parser.add_argument("state", type=Path)
    parser.add_argument("--graphics-probe", action="store_true")
    parser.add_argument("--nspr-version", default="4.40")
    args = parser.parse_args()
    assert os.getuid() != 0, "use an unprivileged test user"
    assert {path.name for path in Path("/sys/class/net").iterdir()} == {"lo"}
    assert not any(key.startswith("MOZ_DISABLE_") for key in os.environ)
    with tempfile.TemporaryDirectory(prefix="librewolf-", dir=args.state) as private:
        state = Path(private)
        environment = os.environ.copy()
        for variable in (
            "HOME",
            "TMPDIR",
            "XDG_CONFIG_HOME",
            "XDG_CACHE_HOME",
            "XDG_DATA_HOME",
            "XDG_RUNTIME_DIR",
        ):
            directory = state / variable.lower()
            directory.mkdir(mode=0o700)
            environment[variable] = str(directory)
        profile = state / "profile"
        profile.mkdir()
        with socket.socket() as reservation:
            reservation.bind(("127.0.0.1", 0))
            port = reservation.getsockname()[1]
        (profile / "user.js").write_text(f'user_pref("marionette.port", {port});\n')
        with http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler) as server:
            threading.Thread(target=server.serve_forever, daemon=True).start()
            with (state / "browser.log").open("w+") as log:
                process = subprocess.Popen(
                    [
                        str(args.browser),
                        "--headless",
                        "--marionette",
                        "--no-remote",
                        "--profile",
                        str(profile),
                    ],
                    env=environment,
                    stdout=log,
                    stderr=subprocess.STDOUT,
                )
                try:
                    deadline = time.monotonic() + 45
                    while True:
                        assert process.poll() is None, "browser exited during startup"
                        try:
                            connection = socket.create_connection(
                                ("127.0.0.1", port), 30
                            )
                            break
                        except ConnectionRefusedError:
                            assert time.monotonic() < deadline, (
                                "Marionette startup timed out"
                            )
                            time.sleep(0.1)
                    with connection:
                        client = Marionette(connection)
                        session = client.command("WebDriver:NewSession", {})
                        assert (
                            session["capabilities"]["browserVersion"] == args.version
                        ), session
                        client.command(
                            "WebDriver:Navigate",
                            {"url": f"http://127.0.0.1:{server.server_port}/"},
                        )
                        assert (
                            client.script(
                                "return document.querySelector('#result').dataset.result"
                            )
                            == "pass"
                        )
                        screenshot = base64.b64decode(
                            client.command(
                                "WebDriver:TakeScreenshot",
                                {
                                    "id": None,
                                    "full": False,
                                    "hash": False,
                                    "scroll": False,
                                },
                            )["value"],
                            validate=True,
                        )
                        assert screenshot.startswith(b"\x89PNG\r\n\x1a\n")
                        (args.state / "librewolf.png").write_bytes(screenshot)
                        parent = dict(
                            line.split(":", 1)
                            for line in Path(f"/proc/{process.pid}/status")
                            .read_text()
                            .splitlines()
                            if ":" in line
                        )
                        print("Parent Seccomp:", parent["Seccomp"].strip())
                        assert parent["Seccomp"].strip() == "0", (
                            "content sandbox evidence must not be an inherited container filter"
                        )
                        statuses = {}
                        for status in Path("/proc").glob("[0-9]*/status"):
                            try:
                                fields = dict(
                                    line.split(":", 1)
                                    for line in status.read_text().splitlines()
                                    if ":" in line
                                )
                            except (FileNotFoundError, PermissionError):
                                continue
                            statuses[int(status.parent.name)] = fields
                        descendants = {process.pid}
                        while True:
                            found = {
                                pid
                                for pid, fields in statuses.items()
                                if int(fields["PPid"]) in descendants
                            }
                            if found <= descendants:
                                break
                            descendants.update(found)
                        children = [
                            fields
                            for pid, fields in statuses.items()
                            if pid in descendants and pid != process.pid
                        ]
                        for child in children:
                            print(
                                "Child:",
                                child["Name"].strip(),
                                "Seccomp:",
                                child["Seccomp"].strip(),
                                "NoNewPrivs:",
                                child["NoNewPrivs"].strip(),
                            )
                        assert any(
                            "Web" in child["Name"]
                            and child["Seccomp"].strip() == "2"
                            and child["NoNewPrivs"].strip() == "1"
                            for child in children
                        )
                        libraries = Path(f"/proc/{process.pid}/maps").read_text()
                        assert "nss-rapid-3.129/lib/nss/libnss3.so" in libraries
                        assert f"nspr-{args.nspr_version}/lib/libnspr4.so" in libraries
                        print(
                            "PASS: browser actually loads the selected NSS/NSPR libraries"
                        )
                        client.command("WebDriver:DeleteSession", {})
                        print(
                            "PASS: installed LibreWolf renders local JavaScript and a screenshot"
                        )
                finally:
                    process.terminate()
                    try:
                        process.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait(timeout=5)
                    log.seek(0)
                    print(log.read())
                    server.shutdown()
        nss = ctypes.CDLL("/profile/lib/nss/libnss3.so")
        nss.NSS_GetVersion.restype = ctypes.c_char_p
        assert nss.NSS_GetVersion().decode() == "3.129"
        nspr = ctypes.CDLL("/profile/lib/libnspr4.so")
        nspr.PR_GetVersion.restype = ctypes.c_char_p
        assert nspr.PR_GetVersion().decode() == args.nspr_version
        print(
            "NSS:",
            nss.NSS_GetVersion().decode(),
            "NSPR:",
            nspr.PR_GetVersion().decode(),
        )
        database = state / "nss-database"
        database.mkdir()
        subprocess.run(
            ["/profile/certutil", "-N", "-d", f"sql:{database}", "--empty-password"],
            env=environment,
            check=True,
            timeout=20,
        )
        subprocess.run(
            ["/profile/certutil", "-L", "-d", f"sql:{database}"],
            env=environment,
            check=True,
            timeout=20,
        )
        print("PASS: AutoFirma-related NSS/NSPR libraries and isolated SQL database")
        if args.graphics_probe:
            with (state / "xvfb.log").open("w+") as error:
                display = subprocess.Popen(
                    [
                        "Xvfb",
                        "-displayfd",
                        "1",
                        "-screen",
                        "0",
                        "1280x720x24",
                        "-nolisten",
                        "tcp",
                    ],
                    env=environment,
                    stdout=subprocess.PIPE,
                    stderr=error,
                )
                try:
                    assert display.stdout is not None
                    number = display.stdout.readline().decode().strip()
                    assert number.isdigit(), "Xvfb did not publish a display"
                    probe_environment = environment.copy()
                    probe_environment["DISPLAY"] = ":" + number
                    root = args.browser.parent.parent
                    wrapper = (root / "lib/librewolf/librewolf").read_text()
                    library_path = re.search(
                        r'export LD_LIBRARY_PATH="([^"$]*)', wrapper
                    )
                    assert library_path, "browser library-path wrapper missing"
                    probe_environment["LD_LIBRARY_PATH"] = library_path[1]
                    result = subprocess.run(
                        [str(root / "lib/librewolf/gfxtest"), "glx"],
                        env=probe_environment,
                        capture_output=True,
                        text=True,
                        timeout=30,
                        check=False,
                    )
                    print(
                        "Graphics probe:",
                        result.returncode,
                        result.stdout,
                        result.stderr,
                    )
                    result.check_returncode()
                    assert "libpci missing" not in result.stdout + result.stderr
                    assert "VENDOR\n" in result.stdout
                    assert "RENDERER\n" in result.stdout
                    assert "ERROR\n" not in result.stdout
                finally:
                    display.terminate()
                    display.wait(timeout=10)
                    error.seek(0)
                    print(error.read())


if __name__ == "__main__":
    main()
