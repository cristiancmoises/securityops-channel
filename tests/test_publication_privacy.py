"""Guard the channel snapshot against private-network and draft content."""

import re
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PRIVATE_LAN = re.compile(
    r"\b(?:192\.168|172\.(?:1[6-9]|2[0-9]|3[01]))\.\d{1,3}\.\d{1,3}\b"
)


class PublicationPrivacyTests(unittest.TestCase):
    def test_tracked_snapshot_has_no_private_lan_literals_or_draft_files(self):
        tracked = (
            subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT)
            .decode()
            .split("\0")
        )
        findings = []
        for relative in filter(None, tracked):
            path = ROOT / relative
            if not path.is_file():
                continue
            text = path.read_text(encoding="utf-8", errors="replace")
            if PRIVATE_LAN.search(text):
                findings.append(relative)
            if relative.startswith("docs/superpowers/"):
                findings.append(relative)
        self.assertEqual(findings, [], "private network or draft files remain")


if __name__ == "__main__":
    unittest.main()
