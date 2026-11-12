import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

CURRENT_RELEASES = (
    ("PipeWire", "1.6.11"),
    ("Arelle", "2.47.4"),
    ("sdb", "2.6.2"),
    ("Tor", "0.4.9.16"),
    ("Tor Browser", "16.0.1"),
    ("yt-dlp", "2026.10.26"),
    ("OpenShot", "4.1.1"),
    ("XLibre Server", "25.2.3"),
    ("Google Chrome", "157.0.8103.78-1"),
    ("Ungoogled Chromium", "156.0.8078.79-1"),
    ("Zabbix", "7.4.16"),
    ("AusweisApp", "2.6.1"),
    ("MoneyPrinterTurbo", "1.3.10"),
    ("Wazuh agent/manager", "4.14.10"),
)


class ReleaseDocumentationTests(unittest.TestCase):
    def test_readmes_list_current_stable_recipes(self):
        for name in ("README.md", "README.pt-BR.md"):
            document = (ROOT / name).read_text(encoding="utf-8")
            with self.subTest(document=name):
                for package, version in CURRENT_RELEASES:
                    self.assertIn(f"| {package} | {version} |", document)

    def test_usage_guide_matches_current_ausweisapp_recipe(self):
        document = (ROOT / "docs/usage.md").read_text(encoding="utf-8")
        self.assertIn("| `ausweisapp` 2.6.1 |", document)
        self.assertNotIn("| `ausweisapp` 2.6.0 |", document)
        self.assertIn("Wazuh agent and manager 4.14.10", document)


if __name__ == "__main__":
    unittest.main()
