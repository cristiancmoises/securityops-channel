"""The public substitute service recovers from a live but wedged publisher."""

import importlib.util
import unittest
from pathlib import Path
from unittest.mock import Mock

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "etc/build-farm/guix-publish-health.py"


def load_module():
    spec = importlib.util.spec_from_file_location("guix_publish_health", SCRIPT)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {SCRIPT}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class PublishHealthTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.health = load_module()

    def test_healthy_publisher_is_not_restarted(self):
        restart = Mock()
        sleep = Mock()
        result = self.health.ensure_healthy(lambda: True, restart, sleep)
        self.assertEqual(result, "healthy")
        restart.assert_not_called()
        sleep.assert_not_called()

    def test_transient_probe_failure_does_not_restart(self):
        probe = Mock(side_effect=[False, True])
        restart = Mock()
        sleep = Mock()
        result = self.health.ensure_healthy(probe, restart, sleep)
        self.assertEqual(result, "healthy")
        restart.assert_not_called()
        sleep.assert_called_once_with(2)

    def test_confirmed_failure_restarts_and_requires_recovery(self):
        probe = Mock(side_effect=[False, False, False, True])
        restart = Mock()
        sleep = Mock()
        result = self.health.ensure_healthy(probe, restart, sleep)
        self.assertEqual(result, "restarted")
        restart.assert_called_once_with()
        self.assertEqual(
            [call.args for call in sleep.call_args_list], [(2,), (1,), (1,)]
        )

    def test_persistent_failure_is_reported_after_bounded_checks(self):
        restart = Mock()
        sleep = Mock()
        with self.assertRaisesRegex(RuntimeError, "did not recover"):
            self.health.ensure_healthy(lambda: False, restart, sleep)
        restart.assert_called_once_with()
        self.assertEqual(sleep.call_count, 21)

    def test_units_run_the_fixed_probe_every_minute(self):
        service = (
            ROOT / "etc/build-farm/units/securityops-guix-publish-health.service"
        ).read_text()
        timer = (
            ROOT / "etc/build-farm/units/securityops-guix-publish-health.timer"
        ).read_text()
        self.assertIn(
            "ExecStart=/usr/local/libexec/securityops-guix-publish-health", service
        )
        self.assertIn("NoNewPrivileges=yes", service)
        self.assertIn("OnUnitActiveSec=1min", timer)
        self.assertIn("Persistent=true", timer)


if __name__ == "__main__":
    unittest.main()
