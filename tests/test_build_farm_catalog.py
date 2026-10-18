"""Strict contract for sanitized System/Home farm inventory."""

import importlib.util
import json
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

MODULE = Path(__file__).resolve().parents[1] / "etc/build-farm/site/catalog.py"
SPEC = importlib.util.spec_from_file_location("farm_site_catalog", MODULE)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("could not load farm catalog")
catalog = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(catalog)

NOW = datetime(2026, 10, 13, 23, 0, tzinfo=timezone.utc)
HASH_A = "a" * 32
HASH_B = "b" * 32
PATH_A = f"/gnu/store/{HASH_A}-example-1.0"
PATH_B = f"/gnu/store/{HASH_B}-example-1.0"
DRV_A = f"/gnu/store/{HASH_A}-example-1.0.drv"


def manifest(source="system", entries=None):
    if entries is None:
        entries = [
            {
                "path": PATH_A,
                "drv": DRV_A,
                "name": "example",
                "version": "1.0",
                "output": "out",
                "kind": "package",
                "direct": True,
            }
        ]
    return {
        "schema": 1,
        "source": source,
        "system": "x86_64-linux",
        "generated_at": "2026-10-13T22:30:00Z",
        "heartbeat_at": "2026-10-13T22:31:00Z",
        "root_drv": DRV_A,
        "root_output": PATH_A,
        "entries": entries,
    }


def payload(value):
    return json.dumps(value, separators=(",", ":")).encode("utf-8")


class CatalogTests(unittest.TestCase):
    def test_accepts_exact_sanitized_manifest(self):
        accepted = catalog.parse_manifest(payload(manifest()), NOW)
        self.assertEqual(accepted["source"], "system")
        self.assertEqual(accepted["entries"][0]["path"], PATH_A)
        self.assertEqual(len(accepted["entries"]), 1)

    def test_accepts_guix_generated_output_with_leading_underscore(self):
        generated = manifest()
        generated["entries"].append(
            {
                "path": f"/gnu/store/{HASH_B}-_guix",
                "drv": f"/gnu/store/{HASH_B}-_guix.drv",
                "name": "_guix",
                "version": "",
                "output": "out",
                "kind": "output",
                "direct": False,
            }
        )
        accepted = catalog.parse_manifest(payload(generated), NOW)
        self.assertEqual(accepted["entries"][1]["name"], "_guix")

    def test_rejects_oversize_duplicate_keys_unknown_fields_and_sources(self):
        with self.assertRaises(ValueError):
            catalog.parse_manifest(b" " * (16 * 1024 * 1024 + 1), NOW)
        duplicate = payload(manifest()).replace(b'"schema":1', b'"schema":1,"schema":1')
        with self.assertRaises(ValueError):
            catalog.parse_manifest(duplicate, NOW)
        invalid = manifest()
        invalid["private_config"] = "/home/berkeley/.config/guix/home.scm"
        with self.assertRaises(ValueError):
            catalog.parse_manifest(payload(invalid), NOW)
        invalid = manifest("extras")
        with self.assertRaises(ValueError):
            catalog.parse_manifest(payload(invalid), NOW)

    def test_rejects_invalid_paths_entry_fields_and_partial_catalog(self):
        for bad_path in (
            "/home/berkeley/example",
            f"/gnu/store/{HASH_A}-../evil",
            f"/gnu/store/{HASH_A}-example/evil",
        ):
            invalid = manifest()
            invalid["entries"][0]["path"] = bad_path
            with self.subTest(path=bad_path), self.assertRaises(ValueError):
                catalog.parse_manifest(payload(invalid), NOW)
        invalid = manifest()
        invalid["entries"][0]["direct"] = 1
        with self.assertRaises(ValueError):
            catalog.parse_manifest(payload(invalid), NOW)
        invalid = manifest()
        invalid["entries"][0]["name"] = '<script>alert("x")</script>'
        with self.assertRaises(ValueError):
            catalog.parse_manifest(payload(invalid), NOW)
        invalid = manifest(entries=[])
        with self.assertRaises(ValueError):
            catalog.parse_manifest(payload(invalid), NOW)

    def test_rejects_duplicate_paths_and_root_not_in_entries(self):
        invalid = manifest()
        invalid["entries"].append(dict(invalid["entries"][0]))
        with self.assertRaises(ValueError):
            catalog.parse_manifest(payload(invalid), NOW)
        invalid = manifest()
        invalid["root_output"] = PATH_B
        with self.assertRaises(ValueError):
            catalog.parse_manifest(payload(invalid), NOW)

    def test_root_output_must_match_its_declared_derivation_and_output(self):
        wrong_root_drv = manifest()
        wrong_root_drv["root_drv"] = f"/gnu/store/{HASH_B}-other.drv"
        wrong_entry_drv = manifest()
        wrong_entry_drv["entries"][0]["drv"] = f"/gnu/store/{HASH_B}-other.drv"
        wrong_output_name = manifest()
        wrong_output_name["entries"][0]["output"] = "debug"
        for invalid in (wrong_root_drv, wrong_entry_drv, wrong_output_name):
            with (
                self.subTest(invalid=invalid),
                self.assertRaisesRegex(ValueError, "root output derivation mismatch"),
            ):
                catalog.parse_manifest(payload(invalid), NOW)

    def test_rejects_future_and_old_upload_timestamps(self):
        invalid = manifest()
        invalid["heartbeat_at"] = "2026-10-14T00:00:00Z"
        with self.assertRaises(ValueError):
            catalog.parse_manifest(payload(invalid), NOW)
        invalid = manifest()
        invalid["generated_at"] = "2026-10-12T22:00:00Z"
        invalid["heartbeat_at"] = "2026-10-12T22:01:00Z"
        with self.assertRaises(ValueError):
            catalog.parse_manifest(payload(invalid), NOW)

    def test_renderer_can_read_old_accepted_manifest_as_stale(self):
        old = manifest()
        old["generated_at"] = "2026-10-12T22:00:00Z"
        old["heartbeat_at"] = "2026-10-12T22:01:00Z"
        with self.assertRaisesRegex(ValueError, "heartbeat"):
            catalog.parse_manifest(payload(old), NOW)
        accepted = catalog.parse_manifest(payload(old), NOW, allow_stale=True)
        self.assertEqual(accepted["source"], "system")
        future = manifest()
        future["heartbeat_at"] = "2026-10-14T00:00:00Z"
        with self.assertRaises(ValueError):
            catalog.parse_manifest(payload(future), NOW, allow_stale=True)

    def test_activity_expires_after_fifteen_minutes(self):
        fresh = {
            "schema": 1,
            "source": "home",
            "updated_at": "2026-10-13T22:59:00Z",
            "active_outputs": [PATH_A],
        }
        accepted = catalog.parse_activity(payload(fresh), NOW)
        target = {"path": PATH_A}
        self.assertEqual(
            catalog.target_state(
                target, set(), set(), {PATH_A: accepted["updated_at"]}, NOW
            ),
            "building",
        )
        old = NOW - timedelta(minutes=16)
        self.assertEqual(
            catalog.target_state(target, set(), set(), {PATH_A: old}, NOW),
            "unavailable",
        )
        self.assertEqual(
            catalog.target_state(target, {PATH_A}, set(), {PATH_A: old}, NOW),
            "available",
        )
        self.assertEqual(
            catalog.target_state(target, set(), {PATH_A}, {PATH_A: NOW}, NOW),
            "stored",
        )

    def test_activity_rejects_duplicate_and_invalid_exact_outputs(self):
        activity = {
            "schema": 1,
            "source": "home",
            "updated_at": "2026-10-13T22:59:00Z",
            "active_outputs": [PATH_A, PATH_A],
        }
        with self.assertRaises(ValueError):
            catalog.parse_activity(payload(activity), NOW)
        activity["active_outputs"] = ["/home/berkeley/secret"]
        with self.assertRaises(ValueError):
            catalog.parse_activity(payload(activity), NOW)
        activity["active_outputs"] = [{"path": PATH_A}]
        with self.assertRaises(ValueError):
            catalog.parse_activity(payload(activity), NOW)

    def test_exact_path_dedup_keeps_memberships_and_distinct_variants(self):
        system = catalog.parse_manifest(payload(manifest()), NOW)
        home_manifest = manifest("home")
        home_manifest["entries"].append(
            {
                **home_manifest["entries"][0],
                "path": PATH_B,
                "drv": f"/gnu/store/{HASH_B}-example-1.0.drv",
                "direct": False,
            }
        )
        home = catalog.parse_manifest(payload(home_manifest), NOW)
        channel = [
            {
                "path": PATH_A,
                "job": "applications.example.x86_64-linux",
                "name": "example-1.0",
            }
        ]
        targets = catalog.merge_targets([system, home], channel)
        self.assertEqual(len(targets), 2)
        by_path = {target["path"]: target for target in targets}
        self.assertEqual(by_path[PATH_A]["sources"], ["channel", "home", "system"])
        self.assertEqual(
            by_path[PATH_A]["direct_sources"], ["channel", "home", "system"]
        )
        self.assertEqual(by_path[PATH_B]["sources"], ["home"])
        self.assertEqual(by_path[PATH_B]["direct_sources"], [])


if __name__ == "__main__":
    unittest.main()
