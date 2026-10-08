"""Exercise RustDesk in a container with a private home and no host network."""

import argparse
import contextlib
import os
import socket
import sqlite3
import subprocess
import tempfile
import time
from pathlib import Path


@contextlib.contextmanager
def running(command: list[str], directory: Path, environment: dict[str, str]):
    # Server logs can contain freshly generated keys; never print their contents.
    with tempfile.TemporaryFile() as log:
        process = subprocess.Popen(
            command, cwd=directory, env=environment, stdout=log, stderr=log
        )
        try:
            yield process
        finally:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)


def output(command: list[str], environment: dict[str, str]) -> str:
    return subprocess.check_output(
        command, env=environment, stderr=subprocess.STDOUT, text=True, timeout=15
    )


def wait_port(process: subprocess.Popen, port: int) -> None:
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        assert process.poll() is None, "server exited before readiness"
        try:
            with socket.create_connection(("127.0.0.1", port), timeout=0.2):
                return
        except OSError:
            time.sleep(0.1)
    raise AssertionError(f"loopback port {port} was not ready")


def websocket_upgrade(port: int) -> None:
    request = (
        "GET / HTTP/1.1\r\nHost: localhost\r\nUpgrade: websocket\r\n"
        "Connection: Upgrade\r\nSec-WebSocket-Version: 13\r\n"
        "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n\r\n"
    )
    with socket.create_connection(("127.0.0.1", port), timeout=3) as connection:
        connection.sendall(request.encode("ascii"))
        response = connection.recv(4096)
    assert response.startswith(b"HTTP/1.1 101"), "WebSocket upgrade failed"


def server_test(prefix: Path, directory: Path, environment: dict[str, str]) -> None:
    for executable in ("hbbs", "hbbr"):
        binary = str(prefix / "bin" / executable)
        assert output([binary, "--version"], environment).strip() == (
            f"{executable} 1.1.16"
        )
        assert "--port" in output([binary, "--help"], environment)

    # The caller creates an isolated network namespace; these ports never bind
    # on host interfaces.  Distinct working directories avoid shared state.
    for executable, port, other_ports in (
        ("hbbs", 32116, (32115, 32118)),
        ("hbbr", 32117, (32119,)),
    ):
        state = directory / executable
        state.mkdir(mode=0o700)
        command = [str(prefix / "bin" / executable), "-p", str(port), "-k", "_"]
        if executable == "hbbs":
            command += ["-r", "127.0.0.1:32117"]
        with running(command, state, environment) as process:
            for checked_port in (port, *other_ports):
                wait_port(process, checked_port)
            websocket_upgrade(port + 2)
            if executable == "hbbs":
                assert (state / "id_ed25519").stat().st_size > 0
                assert (state / "id_ed25519.pub").stat().st_size > 0
                assert (state / "db_v2.sqlite3").stat().st_size > 0
    print("PASS: hbbs/hbbr versions, help, TCP readiness, WebSockets and state")


def client_test(prefix: Path, directory: Path, environment: dict[str, str]) -> None:
    binary = str(prefix / "bin/rustdesk")
    assert output([binary, "--version"], environment).strip() == "1.4.9"
    print("PASS: client version and dynamic library loading")
    environment["DISPLAY"] = ":87"
    with running(
        ["Xvfb", ":87", "-screen", "0", "1280x800x24", "-nolisten", "tcp"],
        directory,
        environment,
    ):
        deadline = time.monotonic() + 10
        while not Path("/tmp/.X11-unix/X87").exists():
            assert time.monotonic() < deadline, "Xvfb did not start"
            time.sleep(0.1)
        with running([binary], directory, environment) as process:
            deadline = time.monotonic() + 25
            while time.monotonic() < deadline:
                assert process.poll() is None, "client exited during GUI startup"
                windows = output(["xwininfo", "-root", "-tree"], environment)
                if '"RustDesk"' in windows or '"rustdesk"' in windows:
                    print("PASS: client created a window on isolated Xvfb")
                    return
                time.sleep(0.2)
    raise AssertionError("client did not create its Flutter window")


def rendezvous_test(
    client: Path, server: Path, directory: Path, environment: dict[str, str]
) -> None:
    """Prove registration only, not an authenticated session or relay traffic."""
    state = directory / "server"
    state.mkdir(mode=0o700)
    environment["DISPLAY"] = ":88"
    display_socket = Path("/tmp/.X11-unix/X88")
    assert not display_socket.exists(), "refusing an existing display socket"
    with running(
        [str(server / "bin/hbbs"), "-p", "32116", "-k", "_", "-r", "127.0.0.1:32117"],
        state,
        environment,
    ) as hbbs:
        wait_port(hbbs, 32116)
        # Both servers use the same freshly generated test key.  Nothing is
        # installed or copied to a user profile; the enclosing tempdir owns it.
        with (
            running(
                [str(server / "bin/hbbr"), "-p", "32117", "-k", "_"],
                state,
                environment,
            ) as hbbr,
            running(
                ["Xvfb", ":88", "-screen", "0", "1280x800x24", "-nolisten", "tcp"],
                directory,
                environment,
            ) as display,
        ):
            wait_port(hbbr, 32117)
            config = Path(environment["XDG_CONFIG_HOME"]) / "rustdesk"
            config.mkdir(mode=0o700)
            public_key = (state / "id_ed25519.pub").read_text().strip()
            (config / "RustDesk2.toml").write_text(
                '[options]\ncustom-rendezvous-server = "127.0.0.1:32116"\n'
                'relay-server = "127.0.0.1:32117"\n'
                f'key = "{public_key}"\n'
            )
            database = state / "db_v2.sqlite3"
            with sqlite3.connect(database, timeout=1) as connection:
                assert (
                    connection.execute("SELECT count(*) FROM peer").fetchone()[0] == 0
                )
            deadline = time.monotonic() + 10
            while not display_socket.exists():
                assert display.poll() is None, "private Xvfb exited"
                assert time.monotonic() < deadline, "private Xvfb startup timed out"
                time.sleep(0.1)
            with running(
                [str(client / "bin/rustdesk")], directory, environment
            ) as process:
                deadline = time.monotonic() + 30
                while time.monotonic() < deadline:
                    assert process.poll() is None, "client exited before rendezvous"
                    assert hbbs.poll() is None and hbbr.poll() is None
                    assert display.poll() is None, "private Xvfb exited"
                    with sqlite3.connect(database, timeout=1) as connection:
                        registered = connection.execute(
                            "SELECT count(*) FROM peer WHERE length(pk) > 0"
                        ).fetchone()[0]
                    if registered == 1:
                        print(
                            "PASS: isolated client registered a peer in loopback hbbs"
                        )
                        print(
                            "NOT TESTED: authenticated session, relay, capture or input"
                        )
                        return
                    time.sleep(0.2)
    raise AssertionError("client did not register in loopback hbbs within 30 seconds")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("client", "server", "rendezvous"))
    parser.add_argument("prefix", type=Path)
    parser.add_argument("--server-prefix", type=Path)
    arguments = parser.parse_args()
    if {name for _, name in socket.if_nameindex()} != {"lo"}:
        parser.error("tests require a private network namespace with only loopback")
    if arguments.mode == "rendezvous" and arguments.server_prefix is None:
        parser.error("rendezvous requires --server-prefix")
    with tempfile.TemporaryDirectory(prefix="rustdesk-test-") as temporary:
        directory = Path(temporary)
        environment = os.environ.copy()
        for name in ("XDG_CONFIG_HOME", "XDG_CACHE_HOME", "XDG_DATA_HOME"):
            location = directory / name.lower()
            location.mkdir(mode=0o700)
            environment[name] = str(location)
        environment.pop("LD_LIBRARY_PATH", None)
        if arguments.mode == "client":
            client_test(arguments.prefix, directory, environment)
        elif arguments.mode == "server":
            server_test(arguments.prefix, directory, environment)
        else:
            rendezvous_test(
                arguments.prefix, arguments.server_prefix, directory, environment
            )


if __name__ == "__main__":
    main()
