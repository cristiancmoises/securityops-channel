"""The CT126 root registrar rejects invalid, untrusted targets."""

import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "etc/build-farm/offload/pin-root"
GUIX = shutil.which("guix")


@unittest.skipUnless(GUIX, "Guix is required for the farm root validation tests")
class PinRootTests(unittest.TestCase):
    def run_pin(self, source, path):
        self.assertTrue(SCRIPT.is_file())
        assert GUIX is not None
        return subprocess.run(
            [GUIX, "repl", "-q", "--", str(SCRIPT), source, path],
            capture_output=True,
            text=True,
            check=False,
            timeout=30,
        )

    def test_rejects_unknown_source(self):
        result = self.run_pin("other", "/gnu/store/" + "a" * 32 + "-fixture")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("source must be system or home", result.stderr)

    def test_rejects_non_store_path(self):
        result = self.run_pin("system", "/tmp/not-a-store-output")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("invalid store output path", result.stderr)

    def test_rejects_missing_store_output(self):
        result = self.run_pin("home", "/gnu/store/" + "a" * 32 + "-fixture")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("store output is not valid", result.stderr)


if __name__ == "__main__":
    unittest.main()
