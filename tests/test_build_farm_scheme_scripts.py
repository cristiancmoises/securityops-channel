"""Guix may load every Scheme file while compiling a channel profile."""

import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which("guix"), "Guix is required")
class ChannelScriptLoadTests(unittest.TestCase):
    def test_tracked_channel_scheme_sources_are_modules(self):
        """Guix channel profiles resolve every tracked .scm as a module."""
        tracked = subprocess.run(
            ["git", "ls-files", "-z", "--", "*.scm"],
            cwd=ROOT,
            capture_output=True,
            check=True,
        ).stdout
        scripts = []
        for relative in tracked.decode().split("\0"):
            if not relative:
                continue
            path = ROOT / relative
            if path.is_file() and not re.search(
                r"(?m)^\s*\(define-module\b", path.read_text()
            ):
                scripts.append(relative)
        self.assertEqual(scripts, [], f"non-module .scm files: {scripts}")

    def assert_load_is_inert(self, script):
        path = ROOT / script
        expression = f'(primitive-load "{path}")\n'
        result = subprocess.run(
            ["guix", "repl", "-q", "--", "/dev/stdin"],
            input=expression,
            text=True,
            capture_output=True,
            cwd=ROOT,
            timeout=60,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_pin_root_is_inert_when_loaded(self):
        self.assert_load_is_inert("etc/build-farm/offload/pin-root")

    def test_export_closure_is_inert_when_loaded(self):
        self.assert_load_is_inert("etc/build-farm/workstation/export-closure")

    def test_pin_root_still_rejects_missing_arguments_when_invoked(self):
        script = ROOT / "etc/build-farm/offload/pin-root"
        result = subprocess.run(
            ["guix", "repl", "-q", "--", str(script)],
            text=True,
            capture_output=True,
            cwd=ROOT,
            timeout=60,
            check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("usage: pin-root", result.stderr)

    def test_installed_pin_root_name_still_executes_validation(self):
        script = ROOT / "etc/build-farm/offload/pin-root"
        with tempfile.TemporaryDirectory() as directory:
            installed = Path(directory) / "securityops-farm-pin-root"
            shutil.copyfile(script, installed)
            result = subprocess.run(
                ["guix", "repl", "-q", "--", str(installed)],
                text=True,
                capture_output=True,
                cwd=ROOT,
                timeout=60,
                check=False,
            )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("usage: pin-root", result.stderr)

    def test_export_closure_still_rejects_missing_arguments_when_invoked(self):
        script = ROOT / "etc/build-farm/workstation/export-closure"
        result = subprocess.run(
            ["guix", "repl", "-q", "--", str(script)],
            text=True,
            capture_output=True,
            cwd=ROOT,
            timeout=60,
            check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("usage: export-closure", result.stderr)


if __name__ == "__main__":
    unittest.main()
