"""Pre-build System/Home on the farm without reconfiguring or compiling locally."""

import importlib.util
import subprocess
import unittest
from datetime import datetime, timezone
from pathlib import Path
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "etc/build-farm/workstation/prebuild.py"


def load_prebuild():
    if not SCRIPT.is_file():
        raise AssertionError("missing workstation prebuild launcher")
    spec = importlib.util.spec_from_file_location("farm_prebuild", SCRIPT)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot import workstation prebuild launcher")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class PrebuildTests(unittest.TestCase):
    def test_build_commands_use_exact_exported_derivation_and_zero_local_jobs(self):
        with patch.dict(
            "os.environ",
            {"SECURITYOPS_FARM_SUBSTITUTE_URL": "https://farm.example.invalid"},
        ):
            prebuild = load_prebuild()
        drv = "/gnu/store/" + "b" * 32 + "-exact-root.drv"
        system = prebuild.build_command("system", drv)
        home = prebuild.build_command("home", drv)
        for command in (system, home):
            self.assertEqual(command[1], "build")
            self.assertEqual(command[-1], drv)
            self.assertEqual(command.count("--max-jobs=0"), 1)
            self.assertTrue(
                any(
                    arg.startswith("--substitute-urls=https://farm.example.invalid")
                    for arg in command
                )
            )
            self.assertNotIn("reconfigure", command)
            self.assertNotIn("--no-offload", command)
        self.assertEqual(system, home)
        with self.assertRaises(ValueError):
            prebuild.build_command("home", "/tmp/not-a-derivation")

        root = "/gnu/store/" + "a" * 32 + "-system"
        self.assertEqual(
            prebuild.copy_command(root),
            [
                str(prebuild.sync.GUIX),
                "copy",
                "--max-jobs=0",
                "--to=farm-copy-ct126",
                root,
            ],
        )
        pin = prebuild.pin_command("system", root)
        self.assertEqual(
            pin[:5], ["ssh", "-T", "-o", "BatchMode=yes", "farm-copy-ct126"]
        )
        self.assertIn("securityops-farm-pin-root system", pin[-1])
        self.assertIn(root, pin[-1])

    def test_long_build_refreshes_only_its_exact_root_and_clears_on_exit(self):
        prebuild = load_prebuild()
        root = "/gnu/store/" + "a" * 32 + "-system"
        drv = "/gnu/store/" + "b" * 32 + "-system.drv"
        process = Mock()
        process.wait.side_effect = [subprocess.TimeoutExpired("build", 300), 0]
        with (
            patch.object(
                prebuild.sync,
                "export_one",
                return_value=(b"manifest", {"root_output": root, "root_drv": drv}),
            ),
            patch.object(prebuild.sync, "upload") as upload,
            patch.object(prebuild.subprocess, "Popen", return_value=process) as popen,
            patch.object(
                prebuild.subprocess,
                "run",
                side_effect=[Mock(returncode=0), Mock(returncode=0)],
            ) as run,
        ):
            self.assertEqual(prebuild.run_source("system"), 0)
        self.assertEqual(upload.call_count, 4)
        self.assertEqual(upload.call_args_list[0].args[0], b"manifest")
        activities = [
            prebuild.sync.catalog.parse_activity(
                call.args[0], datetime.now(timezone.utc)
            )
            for call in upload.call_args_list[1:]
        ]
        self.assertEqual(
            [item["active_outputs"] for item in activities], [[root], [root], []]
        )
        self.assertEqual(popen.call_count, 1)
        self.assertEqual(popen.call_args.args[0], prebuild.build_command("system", drv))
        self.assertEqual(run.call_count, 2)
        self.assertEqual(run.call_args_list[0].args[0], prebuild.copy_command(root))
        self.assertEqual(
            run.call_args_list[1].args[0], prebuild.pin_command("system", root)
        )
        self.assertTrue(
            all(call.kwargs == {"check": False} for call in run.call_args_list)
        )

    def test_failed_build_clears_activity_without_running_reconfigure(self):
        prebuild = load_prebuild()
        root = "/gnu/store/" + "a" * 32 + "-home"
        drv = "/gnu/store/" + "b" * 32 + "-home.drv"
        process = Mock()
        process.wait.return_value = 2
        with (
            patch.object(
                prebuild.sync,
                "export_one",
                return_value=(b"manifest", {"root_output": root, "root_drv": drv}),
            ),
            patch.object(prebuild.sync, "upload") as upload,
            patch.object(prebuild.subprocess, "Popen", return_value=process),
            patch.object(prebuild.subprocess, "run") as run,
        ):
            self.assertEqual(prebuild.run_source("home"), 2)
        run.assert_not_called()
        stopped = prebuild.sync.catalog.parse_activity(
            upload.call_args.args[0], datetime.now(timezone.utc)
        )
        self.assertEqual(stopped["active_outputs"], [])

    def test_copy_failure_is_reported_after_activity_is_cleared(self):
        prebuild = load_prebuild()
        root = "/gnu/store/" + "a" * 32 + "-home"
        drv = "/gnu/store/" + "b" * 32 + "-home.drv"
        process = Mock()
        process.wait.return_value = 0
        with (
            patch.object(
                prebuild.sync,
                "export_one",
                return_value=(b"manifest", {"root_output": root, "root_drv": drv}),
            ),
            patch.object(prebuild.sync, "upload") as upload,
            patch.object(prebuild.subprocess, "Popen", return_value=process),
            patch.object(
                prebuild.subprocess, "run", return_value=Mock(returncode=3)
            ) as run,
        ):
            self.assertEqual(prebuild.run_source("home"), 3)
        run.assert_called_once_with(prebuild.copy_command(root), check=False)
        stopped = prebuild.sync.catalog.parse_activity(
            upload.call_args.args[0], datetime.now(timezone.utc)
        )
        self.assertEqual(stopped["active_outputs"], [])

    def test_pin_failure_is_reported_after_successful_copy(self):
        prebuild = load_prebuild()
        root = "/gnu/store/" + "a" * 32 + "-home"
        drv = "/gnu/store/" + "b" * 32 + "-home.drv"
        process = Mock()
        process.wait.return_value = 0
        with (
            patch.object(
                prebuild.sync,
                "export_one",
                return_value=(b"manifest", {"root_output": root, "root_drv": drv}),
            ),
            patch.object(prebuild.sync, "upload") as upload,
            patch.object(prebuild.subprocess, "Popen", return_value=process),
            patch.object(
                prebuild.subprocess,
                "run",
                side_effect=[Mock(returncode=0), Mock(returncode=4)],
            ) as run,
        ):
            self.assertEqual(prebuild.run_source("home"), 4)
        self.assertEqual(run.call_count, 2)
        stopped = prebuild.sync.catalog.parse_activity(
            upload.call_args.args[0], datetime.now(timezone.utc)
        )
        self.assertEqual(stopped["active_outputs"], [])


if __name__ == "__main__":
    unittest.main()
