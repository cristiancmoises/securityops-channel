"""Reconcile every channel package with one Cuirass job and derivation."""

import importlib.util
import json
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).resolve().parents[1] / "etc/build-farm/reconcile.py"


def load_module():
    spec = importlib.util.spec_from_file_location("build_farm_reconcile", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {MODULE_PATH}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


INVENTORY = (
    "zupt\tzupt\tzupt\t5.2.9\thttps://example.org/zupt\n"
    "wazuh\twazuh-agent\twazuh-agent\t4.14.8\thttps://example.org/wazuh\n"
)
JOBS = [
    {"name": "zupt.zupt.x86_64-linux", "build": 11, "status": 0},
    {"name": "wazuh.wazuh-agent.x86_64-linux", "build": 12, "status": 1},
]
BUILDS = {
    11: {
        "id": 11,
        "job": "zupt.zupt.x86_64-linux",
        "nixname": "zupt-5.2.9",
        "system": "x86_64-linux",
    },
    12: {
        "id": 12,
        "job": "wazuh.wazuh-agent.x86_64-linux",
        "nixname": "wazuh-agent-4.14.8",
        "system": "x86_64-linux",
    },
}


class ReconcileTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.module = load_module()

    def compare(self, inventory=INVENTORY, jobs=None, builds=None):
        return self.module.reconcile(
            inventory,
            json.dumps(JOBS if jobs is None else jobs),
            BUILDS if builds is None else builds,
            "x86_64-linux",
        )

    def test_exact_match_accepts_queued_and_failed_jobs(self):
        report = self.compare()
        self.assertTrue(report["ok"])
        self.assertEqual(report["inventory_count"], 2)
        self.assertEqual(report["job_count"], 2)

    def test_missing_package_reports_exact_identity(self):
        report = self.compare(jobs=JOBS[:1])
        self.assertFalse(report["ok"])
        self.assertIn("wazuh.wazuh-agent@4.14.8", report["missing"])

    def test_duplicate_job_fails_even_when_counts_match(self):
        report = self.compare(jobs=[JOBS[0], JOBS[0]])
        self.assertFalse(report["ok"])
        self.assertIn("zupt.zupt.x86_64-linux", report["duplicates"])

    def test_malformed_jobs_json_is_rejected(self):
        with self.assertRaises(ValueError):
            self.module.reconcile(INVENTORY, "{", BUILDS, "x86_64-linux")

    def test_changed_version_is_not_accepted_by_name_alone(self):
        stale = {**BUILDS, 11: {**BUILDS[11], "nixname": "zupt-5.2.8"}}
        report = self.compare(builds=stale)
        self.assertFalse(report["ok"])
        self.assertIn("zupt.zupt@5.2.9", report["version_mismatch"])

    def test_ambiguous_inventory_name_fails_closed(self):
        report = self.compare(inventory=INVENTORY + INVENTORY.splitlines(True)[0])
        self.assertFalse(report["ok"])
        self.assertIn("zupt.zupt@5.2.9", report["inventory_duplicates"])

    def test_wrong_system_and_job_metadata_fail(self):
        changed = {**BUILDS, 11: {**BUILDS[11], "system": "aarch64-linux"}}
        report = self.compare(builds=changed)
        self.assertFalse(report["ok"])
        self.assertIn("zupt.zupt@5.2.9", report["metadata_mismatch"])

    def test_two_distinct_exports_of_same_package_name_are_both_required(self):
        inventory = (
            "games\tsteam\tsteam\t1.0.0.87\thttps://example.org\n"
            "nvidia\tsteam-nvidia-new-feature\tsteam\t1.0.0.87\thttps://example.org\n"
        )
        jobs = [
            {"name": "games.steam.x86_64-linux", "build": 21},
            {"name": "nvidia.steam-nvidia-new-feature.x86_64-linux", "build": 22},
        ]
        builds = {
            21: {
                "id": 21,
                "job": jobs[0]["name"],
                "nixname": "steam-1.0.0.87",
                "system": "x86_64-linux",
            },
            22: {
                "id": 22,
                "job": jobs[1]["name"],
                "nixname": "steam-1.0.0.87",
                "system": "x86_64-linux",
            },
        }
        self.assertTrue(self.compare(inventory, jobs, builds)["ok"])


if __name__ == "__main__":
    unittest.main()
