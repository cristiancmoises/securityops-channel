"""The farm inventory follows channel exports and exact System/Home targets."""

import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "etc/build-farm/package-inventory"
EXPORTER = ROOT / "etc/build-farm/workstation/export-closure"
SYNC = ROOT / "etc/build-farm/workstation/sync-inventory.py"
CATALOG = ROOT / "etc/build-farm/site/catalog.py"
CATALOG_SPEC = importlib.util.spec_from_file_location("farm_catalog_inventory", CATALOG)
if CATALOG_SPEC is None or CATALOG_SPEC.loader is None:
    raise RuntimeError("could not load farm catalog")
catalog = importlib.util.module_from_spec(CATALOG_SPEC)
CATALOG_SPEC.loader.exec_module(catalog)


def load_sync():
    spec = importlib.util.spec_from_file_location("farm_sync_inventory", SYNC)
    if spec is None or spec.loader is None:
        raise RuntimeError("could not load inventory sync")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class InventoryTests(unittest.TestCase):
    def test_architecture_inventory_preserves_unsupported_exports_separately(self):
        def inventory(*arguments):
            result = subprocess.run(
                ["guix", "repl", "-q", "-L", ".", "--", str(SCRIPT), *arguments],
                cwd=ROOT,
                capture_output=True,
                text=True,
                timeout=180,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            return {tuple(line.split("\t")) for line in result.stdout.splitlines()}

        all_rows = inventory()
        native = inventory("--system", "x86_64-linux")
        unsupported = inventory("--unsupported-system", "x86_64-linux")
        self.assertEqual(
            {row[1] for row in unsupported},
            {"xlibre-video-freedreno", "xlibre-video-geode", "xlibre-video-ps3"},
        )
        self.assertFalse(native & unsupported)
        self.assertEqual(native | unsupported, all_rows)
        self.assertIn("xlibre-server", {row[1] for row in native})
        self.assertEqual(sum(row[2] == "steam" for row in native), 2)

    def test_inventory_rejects_unknown_selection_arguments(self):
        result = subprocess.run(
            [
                "guix",
                "repl",
                "-q",
                "-L",
                ".",
                "--",
                str(SCRIPT),
                "--sysem",
                "x86_64-linux",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            timeout=180,
            check=False,
        )
        self.assertNotEqual(result.returncode, 0)

    def test_prebuild_activity_starts_for_exact_root_and_stops_without_export(self):
        sync = load_sync()
        root = "/gnu/store/" + "a" * 32 + "-fixture"
        with (
            patch.object(
                sync,
                "export_one",
                return_value=(
                    b"manifest",
                    {
                        "root_output": root,
                        "root_drv": root + ".drv",
                        "entries": [{"path": root}],
                    },
                ),
            ) as export,
            patch.object(sync, "upload") as upload,
        ):
            self.assertEqual(
                sync.main(["--source", "system", "--activity", "start"]), 0
            )
            self.assertEqual(upload.call_count, 2)
            self.assertEqual(upload.call_args_list[0].args[0], b"manifest")
            started = catalog.parse_activity(
                upload.call_args_list[1].args[0], datetime.now(timezone.utc)
            )
            self.assertEqual(started["active_outputs"], [root])
            self.assertEqual(sync.main(["--source", "system", "--activity", "stop"]), 0)
            self.assertEqual(export.call_count, 1)
            stopped = catalog.parse_activity(
                upload.call_args.args[0], datetime.now(timezone.utc)
            )
            self.assertEqual(stopped["active_outputs"], [])

    def test_upload_pins_ct126_host_key_and_dedicated_identity(self):
        sync = load_sync()
        with (
            patch.object(sync, "SSH_TARGET", "farm-inventory@example.invalid"),
            patch.object(sync.subprocess, "run") as run,
        ):
            run.return_value.returncode = 0
            sync.upload(b"sanitized manifest")
        args = run.call_args.args[0]
        self.assertIn("StrictHostKeyChecking=yes", args)
        self.assertIn("IdentitiesOnly=yes", args)
        self.assertIn(f"UserKnownHostsFile={sync.SSH_KNOWN_HOSTS}", args)
        self.assertIn(str(sync.SSH_IDENTITY), args)
        self.assertEqual(run.call_args.kwargs["input"], b"sanitized manifest")

    def test_sync_uses_exact_system_and_pinned_home_contexts(self):
        sync = load_sync()
        common = {
            "guix": "/test/guix",
            "exporter": "/test/export-closure",
            "channels": "/test/home-channels.scm",
            "channel": "/test/securityops-channel",
            "substitutes": "http://192.0.2.126:8083",
        }
        self.assertEqual(
            sync.command_for("system", "/test/config-river.scm", **common),
            [
                "/test/guix",
                "repl",
                "-q",
                "-L",
                "/test/securityops-channel",
                "--",
                "/test/export-closure",
                "system",
                "/test/config-river.scm",
            ],
        )
        self.assertEqual(
            sync.command_for("home", "/test/home.scm", **common),
            [
                "/test/guix",
                "time-machine",
                "-C",
                "/test/home-channels.scm",
                "--max-jobs=0",
                "--substitute-urls=http://192.0.2.126:8083",
                "--",
                "repl",
                "-q",
                "--",
                "/test/export-closure",
                "home",
                "/test/home.scm",
            ],
        )

    def test_sync_rejects_wrong_source_from_exporter(self):
        sync = load_sync()
        path = "/gnu/store/" + "a" * 32 + "-fixture"
        drv = path + ".drv"
        stamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        payload = {
            "schema": 1,
            "source": "system",
            "system": "x86_64-linux",
            "generated_at": stamp,
            "heartbeat_at": stamp,
            "root_drv": drv,
            "root_output": path,
            "entries": [
                {
                    "path": path,
                    "drv": drv,
                    "name": "fixture",
                    "version": "1",
                    "output": "out",
                    "kind": "output",
                    "direct": False,
                }
            ],
        }
        command = [
            sys.executable,
            "-c",
            "import sys; sys.stdout.write(sys.argv[1])",
            json.dumps(payload),
        ]
        with self.assertRaisesRegex(ValueError, "source mismatch"):
            sync.export_one("home", command)

    def test_export_allows_a_day_for_remote_kernel_builds(self):
        sync = load_sync()
        with (
            patch.object(sync.subprocess, "run") as run,
            patch.object(
                sync.catalog, "parse_manifest", return_value={"source": "system"}
            ),
        ):
            run.return_value.returncode = 0
            run.return_value.stdout = b"manifest"
            self.assertEqual(
                sync.export_one("system", ["guix", "repl"]),
                (b"manifest", {"source": "system"}),
            )
        self.assertEqual(run.call_args.kwargs["timeout"], 24 * 60 * 60)

    def test_small_home_fixture_exports_exact_direct_and_other_outputs(self):
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / "home.scm"
            config.write_text(
                "(use-modules (gnu home) (gnu packages base))\n"
                "(home-environment (packages (list hello)))\n",
                encoding="utf-8",
            )
            result = subprocess.run(
                ["guix", "repl", "-q", "--", str(EXPORTER), "home", str(config)],
                cwd=ROOT,
                capture_output=True,
                text=True,
                timeout=180,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            value = catalog.parse_manifest(
                result.stdout.encode("utf-8"), datetime.now(timezone.utc)
            )
            self.assertEqual(value["source"], "home")
            entries = value["entries"]
            self.assertIn(value["root_output"], {item["path"] for item in entries})
            self.assertTrue(
                any(item["name"] == "hello" and item["direct"] for item in entries)
            )
            self.assertTrue(any(item["kind"] == "output" for item in entries))
            self.assertGreater(len(entries), 2)

    def test_lxc_offload_ignores_host_wide_load_average(self):
        machine = (ROOT / "etc/build-farm/offload/machines-ct126.scm").read_text()
        self.assertIn("(overload-threshold #f)", machine)
        self.assertIn("(parallel-builds 1)", machine)

    def test_offload_uses_the_stable_ct126_service_address(self):
        machine = (ROOT / "etc/build-farm/offload/machines-ct126.scm").read_text()
        setup = (ROOT / "etc/build-farm/offload/setup-workstation.sh").read_text()
        self.assertIn('"192.168.1.126"', machine)
        self.assertNotIn('"192.168.1.26"', machine)
        self.assertIn(
            "machine_source=/home/berkeley/securityops-channel/etc/build-farm/offload/machines-ct126.scm",
            setup,
        )
        self.assertIn(
            "ff51ae5a0ef9ba646b2acd78257ef498b6773c12ed047c348d6903cdcbdbbbcd",
            setup,
        )
        self.assertIn(
            "374434ac7a3cb8d72dc45ed6a1d73a6ba1d663af2c2f782f0e24670102718032",
            setup,
        )

    def test_every_channel_package_has_a_unique_name_and_version(self):
        result = subprocess.run(
            ["guix", "repl", "-q", "-L", ".", str(SCRIPT)],
            cwd=ROOT,
            capture_output=True,
            text=True,
            timeout=180,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        rows = [line.split("\t") for line in result.stdout.splitlines() if line]
        self.assertGreaterEqual(len(rows), 180)
        self.assertTrue(all(len(row) == 5 for row in rows))
        exports = {(row[0], row[1]) for row in rows}
        self.assertEqual(len(exports), len(rows), "ambiguous exported symbols")
        packages = {(row[2], row[3]) for row in rows}
        self.assertIn(("wazuh-agent", "4.14.9"), packages)
        self.assertIn(("nmap", "7.993"), packages)
        self.assertIn(("glances", "4.5.8"), packages)
        self.assertIn(("arelle", "2.47.3"), packages)
        self.assertIn(("go-github-com-emmansun-base64", "0.11.0"), packages)
        self.assertIn(("go-github-com-ebitengine-purego", "0.11.2"), packages)
        self.assertIn(("zabbix-server", "7.4.16"), packages)
        self.assertIn(("zupt", "5.2.9"), packages)


if __name__ == "__main__":
    unittest.main()
