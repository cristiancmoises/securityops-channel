"""The restricted CT inbox accepts only complete, sanitized manifests."""

import importlib.util
import json
import os
import stat
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
RECEIVER = ROOT / "etc/build-farm/site/receive-manifest.py"
OUTPUT = "/gnu/store/" + "a" * 32 + "-fixture"
DRV = "/gnu/store/" + "b" * 32 + "-fixture.drv"


def receiver_module():
    if not RECEIVER.is_file():
        raise AssertionError("missing restricted manifest receiver")
    spec = importlib.util.spec_from_file_location("farm_manifest_receiver", RECEIVER)
    if spec is None or spec.loader is None:
        raise RuntimeError("receiver cannot be imported")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def manifest(source="system", stamp=None):
    if stamp is None:
        stamp = datetime.now(timezone.utc)
    timestamp = stamp.strftime("%Y-%m-%dT%H:%M:%SZ")
    return json.dumps(
        {
            "schema": 1,
            "source": source,
            "system": "x86_64-linux",
            "generated_at": timestamp,
            "heartbeat_at": timestamp,
            "root_drv": DRV,
            "root_output": OUTPUT,
            "entries": [
                {
                    "path": OUTPUT,
                    "drv": DRV,
                    "name": "fixture",
                    "version": "1",
                    "output": "out",
                    "kind": "output",
                    "direct": False,
                }
            ],
        }
    ).encode("utf-8")


def activity(source="system", paths=None, stamp=None):
    if stamp is None:
        stamp = datetime.now(timezone.utc)
    return json.dumps(
        {
            "schema": 1,
            "source": source,
            "updated_at": stamp.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "active_outputs": [OUTPUT] if paths is None else paths,
        }
    ).encode("utf-8")


class ReceiverTests(unittest.TestCase):
    def test_activity_is_limited_to_accepted_exact_targets_and_can_be_cleared(self):
        receiver = receiver_module()
        with tempfile.TemporaryDirectory() as directory:
            inbox = Path(directory)
            with self.assertRaises(ValueError):
                receiver.receive_payload(activity(), inbox)
            receiver.receive_payload(manifest(), inbox)
            started = activity()
            destination = receiver.receive_payload(started, inbox)
            self.assertEqual(destination.name, "system-activity.json")
            self.assertEqual(destination.read_bytes(), started)
            with self.assertRaises(ValueError):
                receiver.receive_payload(
                    activity(paths=["/gnu/store/" + "c" * 32 + "-unknown"]), inbox
                )
            self.assertEqual(destination.read_bytes(), started)
            cleared = activity(paths=[])
            receiver.receive_payload(cleared, inbox)
            self.assertEqual(destination.read_bytes(), cleared)

    def test_activity_rejects_expired_and_older_updates(self):
        receiver = receiver_module()
        now = datetime.now(timezone.utc)
        with tempfile.TemporaryDirectory() as directory:
            inbox = Path(directory)
            receiver.receive_payload(manifest(stamp=now), inbox, now=now)
            current = activity(stamp=now)
            receiver.receive_payload(current, inbox, now=now)
            with self.assertRaises(ValueError):
                receiver.receive_payload(
                    activity(stamp=now - timedelta(minutes=16)), inbox, now=now
                )
            self.assertEqual((inbox / "system-activity.json").read_bytes(), current)

    def test_ct_ssh_allowlist_keeps_offload_and_adds_only_inventory(self):
        config = (ROOT / "etc/build-farm/offload/sshd-ct126.conf").read_text()
        self.assertIn("AllowUsers guix-offload farm-inventory", config)
        self.assertIn("PasswordAuthentication no", config)

    def test_accepts_only_fixed_source_files_with_private_mode(self):
        receiver = receiver_module()
        with tempfile.TemporaryDirectory() as directory:
            inbox = Path(directory)
            system_payload = manifest("system")
            home_payload = manifest("home")
            self.assertEqual(
                receiver.receive_payload(system_payload, inbox).name, "system.json"
            )
            self.assertEqual(
                receiver.receive_payload(home_payload, inbox).name, "home.json"
            )
            self.assertEqual((inbox / "system.json").read_bytes(), system_payload)
            self.assertEqual((inbox / "home.json").read_bytes(), home_payload)
            self.assertEqual(
                stat.S_IMODE((inbox / "system.json").stat().st_mode), 0o640
            )

    def test_rejects_invalid_input_without_replacing_current(self):
        receiver = receiver_module()
        with tempfile.TemporaryDirectory() as directory:
            inbox = Path(directory)
            original = manifest()
            receiver.receive_payload(original, inbox)
            bad_payloads = (
                b"{bad",
                b"x" * (16 * 1024 * 1024 + 1),
                manifest("channel"),
                manifest(stamp=datetime.now(timezone.utc) - timedelta(hours=25)),
                original[:-1] + b',"config_path":"/home/secret"}',
            )
            for payload in bad_payloads:
                with self.subTest(payload=payload[:40]):
                    with self.assertRaises(ValueError):
                        receiver.receive_payload(payload, inbox)
                    self.assertEqual((inbox / "system.json").read_bytes(), original)

    def test_symlink_target_does_not_escape_inbox(self):
        receiver = receiver_module()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            inbox = root / "inbox"
            inbox.mkdir()
            outside = root / "outside"
            outside.write_text("keep", encoding="utf-8")
            (inbox / "home.json").symlink_to(outside)
            payload = manifest("home")
            receiver.receive_payload(payload, inbox)
            self.assertEqual(outside.read_text(encoding="utf-8"), "keep")
            self.assertFalse((inbox / "home.json").is_symlink())
            self.assertEqual((inbox / "home.json").read_bytes(), payload)

    def test_failed_replace_preserves_previous_and_cleans_temp(self):
        receiver = receiver_module()
        with tempfile.TemporaryDirectory() as directory:
            inbox = Path(directory)
            original = manifest()
            receiver.receive_payload(original, inbox)
            with (
                patch.object(receiver.os, "replace", side_effect=OSError("disk error")),
                self.assertRaises(OSError),
            ):
                receiver.receive_payload(manifest("system"), inbox)
            self.assertEqual((inbox / "system.json").read_bytes(), original)
            self.assertEqual(set(os.listdir(inbox)), {"system.json"})

    def test_older_valid_upload_cannot_roll_back_newer_manifest(self):
        receiver = receiver_module()
        with tempfile.TemporaryDirectory() as directory:
            inbox = Path(directory)
            current = manifest(stamp=datetime.now(timezone.utc))
            receiver.receive_payload(current, inbox)
            older = manifest(stamp=datetime.now(timezone.utc) - timedelta(minutes=10))
            with self.assertRaisesRegex(ValueError, "older"):
                receiver.receive_payload(older, inbox)
            self.assertEqual((inbox / "system.json").read_bytes(), current)

    def test_same_inventory_can_advance_heartbeat(self):
        receiver = receiver_module()
        now = datetime.now(timezone.utc)
        original = manifest(stamp=now - timedelta(minutes=3))
        updated = json.loads(original)
        updated["heartbeat_at"] = (now - timedelta(minutes=1)).strftime(
            "%Y-%m-%dT%H:%M:%SZ"
        )
        refreshed = json.dumps(updated).encode("utf-8")
        with tempfile.TemporaryDirectory() as directory:
            inbox = Path(directory)
            receiver.receive_payload(original, inbox, now=now)
            receiver.receive_payload(refreshed, inbox, now=now)
            self.assertEqual((inbox / "system.json").read_bytes(), refreshed)


if __name__ == "__main__":
    unittest.main()
