"""Exercise tunnel recovery without touching production services."""

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = (
    Path(__file__).resolve().parents[1] / "etc/build-farm/site/evelin-farm-healthcheck"
)


class TunnelHealthTests(unittest.TestCase):
    def run_check(self, responses, *, active=True, restart_ok=True):
        self.assertTrue(SCRIPT.is_file(), "farm tunnel recovery is missing")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "responses").write_text("\n".join(responses) + "\n")
            # Only external effects are replaced; the production shell runs.
            commands = {
                "curl": """#!/bin/bash
printf '%s\\n' "$*" >> "$FIXTURE/probes"
IFS= read -r status < "$FIXTURE/responses"
tail -n +2 "$FIXTURE/responses" > "$FIXTURE/remaining"
mv "$FIXTURE/remaining" "$FIXTURE/responses"
if [[ "$status" == timeout ]]; then exit 28; fi
printf '%s' "$status"
""",
                "systemctl": """#!/bin/bash
printf '%s\\n' "$*" >> "$FIXTURE/actions"
case "$*" in
  'is-active --quiet evelin-farm-forward.service') exit "$ACTIVE_EXIT" ;;
  'try-restart evelin-farm-forward.service') exit "$RESTART_EXIT" ;;
  *) exit 99 ;;
esac
""",
                "sleep": "#!/bin/sh\nexit 0\n",
                "logger": "#!/bin/sh\nexit 0\n",
            }
            for name, content in commands.items():
                command = root / name
                command.write_text(
                    f"#!{shutil.which('bash')}\n" + content.split("\n", 1)[1]
                )
                command.chmod(0o755)
            result = subprocess.run(
                ["bash", str(SCRIPT)],
                env={
                    **os.environ,
                    "PATH": f"{root}:{os.environ['PATH']}",
                    "FIXTURE": str(root),
                    "ACTIVE_EXIT": "0" if active else "3",
                    "RESTART_EXIT": "0" if restart_ok else "1",
                },
                capture_output=True,
                check=False,
                text=True,
                timeout=10,
            )
            actions = (root / "actions").read_text().splitlines()
            probes = (
                (root / "probes").read_text().splitlines()
                if (root / "probes").exists()
                else []
            )
            for probe in probes:
                self.assertIn("--max-time 6", probe)
                self.assertIn("--noproxy *", probe)
                self.assertTrue(probe.endswith("http://127.0.0.1:28126/"))
            return result, actions, probes

    def test_healthy_and_transient_failures_never_restart(self):
        for responses in [["200"], ["502", "200"], ["timeout", "502", "200"]]:
            with self.subTest(responses=responses):
                result, actions, probes = self.run_check(responses)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertFalse(any("restart" in action for action in actions))
                self.assertEqual(len(probes), len(responses))

    def test_three_failures_restart_only_farm_and_verify_recovery(self):
        result, actions, probes = self.run_check(["502", "timeout", "302", "200"])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            [action for action in actions if "restart" in action],
            ["try-restart evelin-farm-forward.service"],
        )
        self.assertEqual(len(probes), 4)

    def test_unrecovered_tunnel_reports_failure_without_restart_loop(self):
        result, actions, probes = self.run_check(["502"] * 4)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(actions.count("try-restart evelin-farm-forward.service"), 1)
        self.assertEqual(len(probes), 4)

    def test_failed_restart_is_reported(self):
        result, actions, probes = self.run_check(["502"] * 3, restart_ok=False)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(actions.count("try-restart evelin-farm-forward.service"), 1)
        self.assertEqual(len(probes), 3)

    def test_manually_stopped_tunnel_is_preserved(self):
        result, actions, probes = self.run_check([], active=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(actions, ["is-active --quiet evelin-farm-forward.service"])
        self.assertEqual(probes, [])


if __name__ == "__main__":
    unittest.main()
