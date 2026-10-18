# SPDX-License-Identifier: GPL-3.0-or-later
"""Host-safe lifecycle checks using synthetic children, never real Wazuh."""

import os
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

SCRIPT = (
    Path(__file__).resolve().parents[1]
    / "securityops/services/aux-files/wazuh-agent-supervisor.py"
)
NAMES = (
    "wazuh-execd",
    "wazuh-agentd",
    "wazuh-syscheckd",
    "wazuh-logcollector",
    "wazuh-modulesd",
)
FAKE = """import os, signal, socket, sys, time
from pathlib import Path
if "-t" in sys.argv: sys.exit(0)
state = Path(os.environ["WAZUH_HOME"])
name = Path(sys.argv[0]).name
(state / (name + ".pid")).write_text(str(os.getpid()))
def stop(*_):
    (state / (name + ".stopped")).touch()
    sys.exit(0)
signal.signal(signal.SIGTERM, stop)
if name in ("wazuh-execd", "wazuh-agentd"):
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
    sock.bind(str(state / "queue/sockets" / ("com" if name == "wazuh-execd" else "queue")))
while True: time.sleep(0.05)
"""


class LifecycleTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="wazuh-fake-lifecycle-")
        self.root = Path(self.temp.name)
        (self.root / "bin").mkdir()
        (self.root / "queue/sockets").mkdir(parents=True)
        for name in NAMES:
            file = self.root / "bin" / name
            file.write_text(f"#!{sys.executable}\n" + FAKE)
            file.chmod(0o700)
        self.process = subprocess.Popen(
            [sys.executable, str(SCRIPT), str(self.root), str(self.root)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            text=True,
        )
        deadline = time.monotonic() + 10
        while len(list(self.root.glob("*.pid"))) != len(NAMES):
            self.assertIsNone(self.process.poll())
            self.assertLess(time.monotonic(), deadline)
            time.sleep(0.05)

    def tearDown(self):
        if self.process.poll() is None:
            self.process.terminate()
        self.process.communicate(timeout=30)
        self.temp.cleanup()

    def test_term_stops_all_foreground_children(self):
        self.process.terminate()
        self.assertEqual(self.process.wait(timeout=5), 0)
        self.assertEqual(len(list(self.root.glob("*.stopped"))), len(NAMES))

    def test_child_failure_stops_siblings_and_fails_supervisor(self):
        target = self.root / "wazuh-logcollector.pid"
        os.kill(int(target.read_text()), signal.SIGKILL)
        self.assertEqual(self.process.wait(timeout=5), 1)
        self.assertEqual(len(list(self.root.glob("*.stopped"))), len(NAMES) - 1)


if __name__ == "__main__":
    unittest.main()
