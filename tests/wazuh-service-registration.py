# SPDX-License-Identifier: GPL-3.0-or-later
"""Load built service expressions in a private, unprivileged Shepherd only.

Usage: python3 tests/wazuh-service-registration.py BUNDLE SHEPHERD-PACKAGE
Neither the bind mount nor the agent is started.
"""

import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path


def main():
    if os.geteuid() == 0:
        raise SystemExit("This registration test must run unprivileged")
    bundle, package = map(Path, sys.argv[1:])
    with tempfile.TemporaryDirectory(
        prefix="wazuh-shepherd-registration-"
    ) as directory:
        socket = str(Path(directory) / "socket")
        process = subprocess.Popen(
            [
                str(package / "bin/shepherd"),
                "--socket",
                socket,
                "--logfile",
                str(Path(directory) / "log"),
                "--config",
                str(bundle / "shepherd.scm"),
            ],
            cwd=directory,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )
        try:
            deadline = time.monotonic() + 10
            while not Path(socket).exists():
                if process.poll() is not None or time.monotonic() > deadline:
                    raise RuntimeError(
                        "Private Shepherd did not load the service bundle"
                    )
                time.sleep(0.1)
            for name in ("wazuh-agent", "file-system-/var/lib/wazuh-agent/gnu/store"):
                result = subprocess.run(
                    [str(package / "bin/herd"), "--socket", socket, "status", name],
                    check=True,
                    capture_output=True,
                    text=True,
                    timeout=10,
                )
                assert "stopped" in result.stdout.lower(), result.stdout
            subprocess.run(
                [str(package / "bin/herd"), "--socket", socket, "stop", "root"],
                check=True,
                capture_output=True,
                timeout=10,
            )
            assert process.wait(timeout=10) == 0
            print("PASS: built agent and read-only mount register without activation")
        finally:
            if process.poll() is None:
                process.terminate()
            output, _ = process.communicate(timeout=10)
            if process.returncode:
                print(output, file=sys.stderr)


if __name__ == "__main__":
    main()
