"""The CT-safe Zupt regression test must keep checking terminal echo."""

import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RECIPE = ROOT / "securityops/packages/zupt.scm"
ARCHIVE = ROOT / "securityops/packages/sources/zupt-5.2.9.tar.gz"
PATCH = ROOT / "securityops/packages/patches/zupt-password-prompt-test-race.patch"


class ZuptPromptPatchTests(unittest.TestCase):
    def test_prompt_race_patch_applies_without_disabling_the_assertions(self):
        self.assertTrue(
            PATCH.name in RECIPE.read_text(encoding="utf-8"),
            "Zupt recipe must apply the prompt test patch",
        )
        with tempfile.TemporaryDirectory() as directory:
            subprocess.run(["tar", "-xzf", str(ARCHIVE), "-C", directory], check=True)
            source = Path(directory) / "zupt-5.2.9"
            subprocess.run(
                ["patch", "--batch", "-p1", "-i", str(PATCH)], cwd=source, check=True
            )
            test = (source / "tests/test_password_prompt_signal.sh").read_text(
                encoding="utf-8"
            )
            self.assertIn("echo_deadline = time.monotonic() + 2", test)
            self.assertIn("terminal echo was not disabled during prompt", test)
            self.assertIn("terminal echo state was not restored after SIGINT", test)


if __name__ == "__main__":
    unittest.main()
