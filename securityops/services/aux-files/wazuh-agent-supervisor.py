# SPDX-License-Identifier: GPL-3.0-or-later
"""Keep Wazuh foreground daemons in one Shepherd-managed lifecycle."""

import signal
import stat
import subprocess
import sys
import threading
import time
from pathlib import Path

DAEMONS = (
    "wazuh-execd",
    "wazuh-agentd",
    "wazuh-syscheckd",
    "wazuh-logcollector",
    "wazuh-modulesd",
)


def stop_children(children):
    for child in reversed(children):
        if child.poll() is None:
            child.terminate()
    deadline = time.monotonic() + 20
    for child in reversed(children):
        try:
            child.wait(timeout=max(0.1, deadline - time.monotonic()))
        except subprocess.TimeoutExpired:
            child.kill()
            child.wait()


def wait_socket(path, children, stopping):
    deadline = time.monotonic() + 30
    while not stopping.is_set():
        if any(child.poll() is not None for child in children):
            raise RuntimeError("A Wazuh daemon exited during startup")
        try:
            if stat.S_ISSOCK(path.stat().st_mode):
                return
        except FileNotFoundError:
            pass
        if time.monotonic() >= deadline:
            raise RuntimeError("Wazuh startup socket did not become ready")
        stopping.wait(0.1)
    raise InterruptedError


def supervise(package, state, stopping, docker_script=None):
    environment = {
        "PATH": "/run/current-system/profile/bin",
        "WAZUH_HOME": str(state),
        "LC_ALL": "C",
    }
    children = []
    collector = None
    retry_at = 0
    try:
        for name in DAEMONS:
            if stopping.is_set():
                return 0
            command = str(package / "bin" / name)
            subprocess.run(
                [command, "-t"], cwd=state, env=environment, check=True, timeout=10
            )
        for name in DAEMONS:
            if stopping.is_set():
                return 0
            children.append(
                subprocess.Popen(
                    [str(package / "bin" / name), "-f"], cwd=state, env=environment
                )
            )
            if name == "wazuh-execd":
                wait_socket(state / "queue/sockets/com", children, stopping)
            elif name == "wazuh-agentd":
                wait_socket(state / "queue/sockets/queue", children, stopping)
        while not stopping.wait(0.5):
            if any(child.poll() is not None for child in children):
                raise RuntimeError("A Wazuh daemon exited; restarting the group")
            if (
                docker_script
                and time.monotonic() >= retry_at
                and (collector is None or collector.poll() is not None)
            ):
                collector = subprocess.Popen(
                    [sys.executable, "-I", "-B", docker_script, str(state)],
                    cwd=state,
                    env=environment,
                )
                retry_at = time.monotonic() + 30
        return 0
    except InterruptedError:
        return 0
    finally:
        stop_children(children + ([collector] if collector else []))


def main():
    if len(sys.argv) not in (3, 4):
        raise SystemExit("usage: wazuh-agent-supervisor PACKAGE STATE [DOCKER-SCRIPT]")
    stopping = threading.Event()
    for sig in (signal.SIGTERM, signal.SIGINT):
        signal.signal(sig, lambda *_: stopping.set())
    try:
        return supervise(
            Path(sys.argv[1]),
            Path(sys.argv[2]),
            stopping,
            sys.argv[3] if len(sys.argv) == 4 else None,
        )
    except (OSError, RuntimeError, subprocess.SubprocessError):
        print(
            "Wazuh agent group failed; inspect the private Wazuh logs", file=sys.stderr
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
