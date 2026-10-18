# SPDX-License-Identifier: GPL-3.0-or-later
"""Host-safe privacy tests: no Docker connection or Wazuh process is started."""

import importlib.util
import unittest
from pathlib import Path

SOURCE = (
    Path(__file__).resolve().parents[1]
    / "securityops/services/aux-files/wazuh-docker-events.py"
)
SPEC = importlib.util.spec_from_file_location("wazuh_docker_events", SOURCE)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class DockerEventTests(unittest.TestCase):
    def test_only_allowlisted_fields_leave_host(self):
        event = {
            "time": 123,
            "Type": "container",
            "Action": "start",
            "id": "abc",
            "Actor": {
                "Attributes": {
                    "name": "web",
                    "image": "nginx:1",
                    "password": "do-not-send",
                    "env": "PRIVATE=secret",
                }
            },
            "Config": {"Env": ["TOKEN=do-not-send"]},
            "private": "do-not-send",
        }
        self.assertEqual(
            MODULE.sanitize_event(event),
            {
                "source": "securityops-docker-safe",
                "integration": "docker",
                "docker": {
                    "time": 123,
                    "type": "container",
                    "action": "start",
                    "id": "abc",
                    "name": "web",
                    "image": "nginx:1",
                },
            },
        )

    def test_nested_or_oversized_values_are_omitted(self):
        result = MODULE.sanitize_event(
            {
                "time": {"private": "secret"},
                "Type": ["private"],
                "Action": "x" * 2049,
                "Actor": {"Attributes": {"name": {"private": "secret"}}},
            }
        )
        self.assertEqual(
            result,
            {
                "source": "securityops-docker-safe",
                "integration": "docker",
                "docker": {},
            },
        )

    def test_malformed_actor_cannot_disclose_nested_data(self):
        self.assertEqual(
            MODULE.sanitize_event({"Actor": ["private"]}), MODULE.sanitize_event({})
        )

    def test_unknown_fields_do_not_change_event(self):
        self.assertEqual(
            MODULE.sanitize_event({"unknown": "secret"}), MODULE.sanitize_event({})
        )

    def test_exec_commands_and_control_characters_are_not_forwarded(self):
        result = MODULE.sanitize_event(
            {
                "Action": "exec_create: env PRIVATE=do-not-send",
                "Actor": {"Attributes": {"name": "web\nprivate"}},
            }
        )
        self.assertEqual(result, MODULE.sanitize_event({}))


if __name__ == "__main__":
    unittest.main()
