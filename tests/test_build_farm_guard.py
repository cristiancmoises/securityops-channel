"""Capacity decisions are fail-closed and never auto-resume a paused farm."""

import importlib.util
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

PATH = Path(__file__).resolve().parents[1] / "etc/build-farm/host-guard.py"


def load_module():
    spec = importlib.util.spec_from_file_location("build_farm_guard", PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {PATH}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class GuardTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.guard = load_module()

    def test_healthy_farm_stays_running(self):
        self.assertEqual(self.guard.pause_reasons(79.99, 84, 4 * 1024**2), [])
        self.assertEqual(self.guard.decide_action([], False), "continue")

    def test_thin_pool_limit_pauses(self):
        self.assertIn("thin-pool", self.guard.pause_reasons(80, 2, 20 * 1024**2))

    def test_builder_disk_limit_pauses(self):
        self.assertIn("builder-disk", self.guard.pause_reasons(10, 85, 20 * 1024**2))

    def test_low_host_memory_pauses(self):
        self.assertIn("host-memory", self.guard.pause_reasons(10, 2, 4 * 1024**2 - 1))

    def test_invalid_metrics_fail_closed(self):
        for values in [(-1, 2, 10), (101, 2, 10), (10, None, 10), (10, 2, -1)]:
            with self.subTest(values=values), self.assertRaises(ValueError):
                self.guard.pause_reasons(*values)

    def test_already_paused_never_resumes_automatically(self):
        self.assertEqual(self.guard.decide_action([], True), "remain-paused")
        self.assertEqual(self.guard.decide_action(["thin-pool"], True), "remain-paused")
        self.assertEqual(self.guard.decide_action(["thin-pool"], False), "pause")

    def test_metric_parsers_reject_unexpected_output(self):
        self.assertEqual(self.guard.parse_lvs("  9.65\n"), 9.65)
        self.assertEqual(
            self.guard.parse_df(
                "Filesystem 1024-blocks Used Available Capacity Mounted on\n"
                "/dev/mapper/x 100 10 90 10% /\n"
            ),
            10.0,
        )
        self.assertEqual(
            self.guard.parse_meminfo("MemAvailable: 5000000 kB\n"), 5000000
        )
        for function, value in [
            (self.guard.parse_lvs, "not-a-number"),
            (self.guard.parse_df, "incomplete"),
            (self.guard.parse_meminfo, "MemFree: 5 kB"),
        ]:
            with self.subTest(function=function), self.assertRaises(ValueError):
                function(value)

    def test_pause_marks_exact_ct_and_registration_unit(self):
        with tempfile.TemporaryDirectory() as temporary:
            marker = Path(temporary) / "PAUSED"
            with (
                patch.object(self.guard, "PAUSE_FILE", marker),
                patch.object(self.guard, "command") as command,
            ):
                self.guard.pause("thin-pool")
            self.assertEqual(marker.read_text(), "thin-pool\n")
            command.assert_called_once_with(
                "pct",
                "exec",
                "126",
                "--",
                "systemctl",
                "disable",
                "--now",
                "securityops-cuirass-register.service",
            )

    def test_existing_pause_marker_retries_stop_without_resuming(self):
        with tempfile.TemporaryDirectory() as temporary:
            marker = Path(temporary) / "PAUSED"
            marker.write_text("thin-pool\n")
            with (
                patch.object(self.guard, "PAUSE_FILE", marker),
                patch.object(
                    self.guard, "collect_metrics", return_value=(1, 1, 8 * 1024**2)
                ),
                patch.object(self.guard, "command") as command,
            ):
                self.assertEqual(self.guard.main(), 1)
            self.assertEqual(marker.read_text(), "thin-pool\n")
            command.assert_called_once_with(
                "pct",
                "exec",
                "126",
                "--",
                "systemctl",
                "disable",
                "--now",
                "securityops-cuirass-register.service",
            )

    def test_existing_pause_marker_reports_failed_stop(self):
        with tempfile.TemporaryDirectory() as temporary:
            marker = Path(temporary) / "PAUSED"
            marker.write_text("metric-error:TimeoutExpired\n")
            with (
                patch.object(self.guard, "PAUSE_FILE", marker),
                patch.object(
                    self.guard, "collect_metrics", return_value=(1, 1, 8 * 1024**2)
                ),
                patch.object(
                    self.guard,
                    "command",
                    side_effect=subprocess.TimeoutExpired("pct", 20),
                ),
            ):
                self.assertEqual(self.guard.main(), 2)
            self.assertEqual(marker.read_text(), "metric-error:TimeoutExpired\n")


if __name__ == "__main__":
    unittest.main()
