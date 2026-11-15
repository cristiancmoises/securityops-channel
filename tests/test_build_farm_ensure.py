"""Recovery honors capacity pauses while keeping the status API available."""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "etc/build-farm/ensure-cuirass-services"


class EnsureServicesTest(unittest.TestCase):
    def test_recovery_respects_enabled_state(self):
        for enabled in (0, 1):
            with (
                self.subTest(enabled=enabled),
                tempfile.TemporaryDirectory() as temporary,
            ):
                root = Path(temporary)
                command = root / "systemctl"
                command.write_text(
                    "#!/bin/sh\n"
                    'case "$1" in\n'
                    'is-enabled) exit "$ENABLED_EXIT";;\n'
                    "is-active) exit 3;;\n"
                    'start) printf "%s\\n" "$2" >> "$CALLS";;\n'
                    "*) exit 99;;\n"
                    "esac\n"
                )
                command.chmod(0o755)
                calls = root / "calls"
                result = subprocess.run(
                    ["sh", str(SCRIPT)],
                    env={
                        **os.environ,
                        "PATH": temporary + os.pathsep + os.environ["PATH"],
                        "ENABLED_EXIT": str(enabled),
                        "CALLS": str(calls),
                    },
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                expected = ["securityops-cuirass-web.service"]
                if enabled == 0:
                    expected.insert(0, "securityops-cuirass-register.service")
                self.assertEqual(calls.read_text().splitlines(), expected)


if __name__ == "__main__":
    unittest.main()
