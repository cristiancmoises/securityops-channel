"""Safety and behavior checks for the host-side public publication bridge."""

import hashlib
import importlib.util
import io
import json
import os
import shutil
import socket
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from datetime import datetime, timezone
from email.message import Message
from pathlib import Path
from unittest.mock import patch
from urllib.error import HTTPError, URLError

MODULE = Path(__file__).resolve().parents[1] / "etc/build-farm/publication/publish.py"
SPEC = importlib.util.spec_from_file_location("farm_publication", MODULE)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("could not load publication bridge")
publication = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(publication)

NOW = datetime(2026, 10, 14, 22, 0, tzinfo=timezone.utc)
ROOT = "/gnu/store/" + "a" * 32 + "-system-root"
PACKAGE = "/gnu/store/" + "b" * 32 + "-free-package-1.0"
FAILED = "/gnu/store/" + "c" * 32 + "-failed-package-1.0"
HOME = "/gnu/store/" + "d" * 32 + "-home-package-1.0"
OTHER = "/gnu/store/" + "e" * 32 + "-generated-output"
DENIED = "/gnu/store/" + "f" * 32 + "-nvidia-driver-1.0"


def entry(path, kind="package"):
    return {
        "path": path,
        "drv": path + ".drv",
        "name": "example",
        "version": "1.0",
        "output": "out",
        "kind": kind,
        "direct": True,
    }


def manifest(source, extra=()):
    return {
        "schema": 1,
        "source": source,
        "system": "x86_64-linux",
        "generated_at": "2026-10-14T21:00:00Z",
        "heartbeat_at": "2026-10-14T21:01:00Z",
        "root_drv": ROOT + ".drv",
        "root_output": ROOT,
        "entries": [entry(ROOT), *extra],
    }


def csv_row(job, status, build_status, path, *, output="out"):
    return (
        f"42,1792011600,{job},{status},12,example-1.0,{build_status},"
        f"1792010000,1792011000,{output},{path}\n"
    )


class PublicationConfigurationTests(unittest.TestCase):
    def test_missing_private_publisher_url_blocks_publication_check(self):
        with (
            patch.object(publication, "CT116_PUBLIC_URL", None),
            patch.object(publication, "check_public_output") as check,
        ):
            with self.assertRaisesRegex(RuntimeError, "SECURITYOPS_CT116_PUBLIC_URL"):
                publication.check_both_publishers(ROOT)
            check.assert_not_called()


class PublicationSelectionTests(unittest.TestCase):
    def test_selects_successful_channel_and_package_manifest_entries_without_roots(
        self,
    ):
        csv = (
            csv_row("channel.root.x86_64-linux", 0, 0, ROOT)
            + csv_row("channel.package.x86_64-linux", 0, 0, PACKAGE)
            + csv_row("channel.failed.x86_64-linux", 1, 1, FAILED)
        )
        snapshot = publication.parse_cuirass_csv(csv)
        system = publication.validate_manifest(
            json.dumps(manifest("system", [entry(OTHER, "output")])).encode(),
            "system",
            NOW,
        )
        home = publication.validate_manifest(
            json.dumps(manifest("home", [entry(HOME)])).encode(),
            "home",
            NOW,
        )

        selected, held = publication.select_targets(snapshot, [system, home])

        self.assertEqual(selected, [PACKAGE, HOME])
        self.assertEqual(held, [{"path": FAILED, "reason": "unsuccessful_job"}])
        self.assertNotIn(ROOT, selected)
        self.assertNotIn(OTHER, selected)

    def test_rejects_stale_manifest_and_invalid_channel_path(self):
        stale = manifest("home", [entry(HOME)])
        stale["heartbeat_at"] = "2026-10-12T21:01:00Z"
        with self.assertRaisesRegex(ValueError, "heartbeat"):
            publication.validate_manifest(json.dumps(stale).encode(), "home", NOW)
        with self.assertRaisesRegex(ValueError, "store path"):
            publication.parse_cuirass_csv(
                csv_row("channel.bad.x86_64-linux", 0, 0, "/tmp/not-a-store-path")
            )

    def test_rejects_mixed_or_incomplete_cuirass_snapshot(self):
        good = csv_row("channel.good.x86_64-linux", 0, 0, PACKAGE)
        with self.assertRaises(ValueError):
            publication.parse_cuirass_csv(good + good)
        with self.assertRaises(ValueError):
            publication.parse_cuirass_csv("")
        with self.assertRaises(ValueError):
            publication.parse_cuirass_csv(good.replace("42,", "43,", 1) + good)

    def test_failed_channel_path_cannot_be_rescued_by_manifest_membership(self):
        snapshot = publication.parse_cuirass_csv(
            csv_row("channel.failed.x86_64-linux", 1, 1, HOME)
        )
        home = publication.validate_manifest(
            json.dumps(manifest("home", [entry(HOME)])).encode(), "home", NOW
        )
        selected, held = publication.select_targets(snapshot, [home])
        self.assertEqual(selected, [])
        self.assertEqual(held, [{"path": HOME, "reason": "unsuccessful_job"}])

    def test_successful_job_without_exact_output_is_reported_held(self):
        snapshot = publication.parse_cuirass_csv(
            csv_row("channel.missing.x86_64-linux", 0, 0, "", output="")
        )
        selected, held = publication.select_targets(snapshot, [])
        self.assertEqual(selected, [])
        self.assertEqual(
            held,
            [{"job": "channel.missing.x86_64-linux", "reason": "missing_output"}],
        )


def reviewed(path=PACKAGE, requisites=(PACKAGE,)):
    digest = hashlib.sha256(("\n".join(sorted(requisites)) + "\n").encode()).hexdigest()
    return publication.parse_policy(
        json.dumps(
            {
                "schema": 1,
                "approved": [
                    {
                        "path": path,
                        "requisites_sha256": digest,
                        "reviewed_by": "release-reviewer",
                        "reviewed_at": "2026-10-14T21:00:00Z",
                        "license_basis": "Source and all requisite redistribution terms reviewed.",
                    }
                ],
                "denied": [],
            }
        ).encode()
    )


class FakeTransport:
    def __init__(
        self, requisites=(PACKAGE,), missing_builder=(), missing_public=(PACKAGE,)
    ):
        self.requisites = requisites
        self.missing_builder = set(missing_builder)
        self.missing_public = set(missing_public)
        self.calls = []
        self.pinned = set()
        self.streamed = []
        self.imported = False
        self.fail_stream = False
        self.fail_disk = False

    def run(self, ct, argv, input=None):
        self.calls.append((ct, argv, input))
        if argv == ["python3", "-c", publication.LIST_PINNED_SCRIPT]:
            hashes = sorted(
                path.removeprefix("/gnu/store/").split("-", 1)[0]
                for pinned_ct, path in self.pinned
                if pinned_ct == 116
            )
            return ("\n".join(hashes) + ("\n" if hashes else "")).encode()
        if argv[1:3] == ["gc", "--requisites"]:
            return ("\n".join(self.requisites) + "\n").encode()
        if argv[1:3] == ["archive", "--missing"]:
            missing = self.missing_builder if ct == 126 else self.missing_public
            if ct == 116 and self.imported:
                missing = set()
            return ("\n".join(sorted(missing)) + ("\n" if missing else "")).encode()
        if argv[:3] == ["python3", "-c", publication.RUN_PIN_SCRIPT]:
            path = next(path for path in self.requisites if path.encode() in input)
            self.pinned.add((ct, path))
            return b""
        if argv[:2] == ["du", "-s"] and "--inodes" in argv:
            return "".join(f"1\t{path}\n" for path in self.requisites).encode()
        if argv[:2] == ["du", "-s"]:
            return "".join(f"1024\t{path}\n" for path in self.requisites).encode()
        raise AssertionError(f"unexpected container command: {ct} {argv}")

    def ensure_capacity(self, archive_bytes, entries):
        self.calls.append(("capacity", archive_bytes, entries))
        if self.fail_disk:
            raise RuntimeError("disk guard stopped publication")

    def stream_archive(self, path, *, max_bytes=None):
        self.streamed.append(path)
        if self.fail_stream:
            raise RuntimeError("archive import failed")
        self.imported = True


class PublicationExecutionTests(unittest.TestCase):
    def test_size_probe_counts_logical_bytes_and_entries(self):
        transport = FakeTransport()
        self.assertEqual(
            publication._closure_footprint(transport, [PACKAGE]), (1024, 1)
        )
        command = transport.calls[0][1]
        self.assertIn("--apparent-size", command)
        self.assertIn("--count-links", command)
        self.assertIn("--inodes", transport.calls[1][1])

    def test_tiny_file_closure_reserves_per_entry_destination_overhead(self):
        transport = FakeTransport()
        original_run = transport.run

        def many_entries(ct, argv, input=None):
            if argv[:2] == ["du", "-s"] and "--inodes" in argv:
                return b"100000\t" + PACKAGE.encode() + b"\n"
            return original_run(ct, argv, input)

        transport.run = many_entries
        publication.publish_paths([PACKAGE], reviewed(), transport, lambda path: False)
        self.assertEqual(
            transport.calls[-1], ("capacity", 1024 + 100000 * 8192, 100000)
        )

    def test_excessive_entry_count_is_held_before_transfer(self):
        transport = FakeTransport()
        original_run = transport.run

        def too_many_entries(ct, argv, input=None):
            if argv[:2] == ["du", "-s"] and "--inodes" in argv:
                return b"1000001\t" + PACKAGE.encode() + b"\n"
            return original_run(ct, argv, input)

        transport.run = too_many_entries
        result = publication.publish_paths(
            [PACKAGE], reviewed(), transport, lambda path: False, apply=True
        )
        self.assertEqual(
            result["held"], [{"path": PACKAGE, "reason": "oversized_closure"}]
        )
        self.assertEqual(transport.streamed, [])

    def test_oversized_closure_is_held_before_transfer(self):
        transport = FakeTransport()
        with patch.object(publication, "MAX_ARCHIVE_BYTES", 512, create=True):
            result = publication.publish_paths(
                [PACKAGE], reviewed(), transport, lambda path: False, apply=True
            )
        self.assertEqual(
            result["held"], [{"path": PACKAGE, "reason": "oversized_closure"}]
        )
        self.assertEqual(transport.streamed, [])

    def test_unknown_and_known_denied_outputs_are_reported_held_without_commands(self):
        transport = FakeTransport()
        result = publication.publish_paths(
            [PACKAGE, DENIED],
            publication.parse_policy(b'{"schema":1,"approved":[],"denied":[]}'),
            transport,
            lambda path: False,
        )
        self.assertEqual(
            result["held"],
            [
                {"path": PACKAGE, "reason": "unreviewed_redistribution"},
                {"path": DENIED, "reason": "known_review_trigger"},
            ],
        )
        self.assertEqual(transport.calls, [])
        self.assertEqual(transport.streamed, [])

    def test_dry_run_preflights_but_never_exports_imports_or_pins(self):
        transport = FakeTransport()
        result = publication.publish_paths(
            [PACKAGE], reviewed(), transport, lambda path: False
        )
        self.assertEqual(result["planned"], [PACKAGE])
        self.assertEqual(result["public_routes_reachable"], [])
        self.assertEqual(transport.streamed, [])
        self.assertEqual(transport.pinned, set())
        self.assertTrue(any(call[0] == "capacity" for call in transport.calls))
        self.assertFalse(
            any(
                "build" in call[1]
                for call in transport.calls
                if isinstance(call[0], int)
            )
        )

    def test_apply_streams_once_and_pins_both_containers(self):
        transport = FakeTransport()
        result = publication.publish_paths(
            [PACKAGE],
            reviewed(),
            transport,
            lambda path: transport.imported,
            apply=True,
        )
        self.assertEqual(result["public_routes_reachable"], [PACKAGE])
        self.assertNotIn("published", result)
        self.assertEqual(transport.streamed, [PACKAGE])
        self.assertEqual(transport.pinned, {(126, PACKAGE), (116, PACKAGE)})

    def test_import_waits_for_pending_narinfo_without_reimporting_or_repinning(self):
        transport = FakeTransport(requisites=(PACKAGE, OTHER))
        checked = []

        def public_check(path):
            self.assertTrue(transport.imported)
            self.assertEqual(transport.pinned, {(126, PACKAGE), (116, PACKAGE)})
            checked.append(path)
            return path == PACKAGE or checked.count(OTHER) == 3

        with patch("time.sleep") as sleep:
            result = publication.publish_paths(
                [PACKAGE],
                reviewed(requisites=(PACKAGE, OTHER)),
                transport,
                public_check,
                apply=True,
            )
        self.assertEqual(result["public_routes_reachable"], [PACKAGE])
        self.assertEqual(checked, [PACKAGE, OTHER, OTHER, OTHER])
        self.assertEqual([call.args for call in sleep.call_args_list], [(10,), (10,)])
        self.assertEqual(transport.streamed, [PACKAGE])
        pins = [
            call
            for call in transport.calls
            if isinstance(call[0], int)
            and call[1][:3] == ["python3", "-c", publication.RUN_PIN_SCRIPT]
        ]
        self.assertEqual([call[0] for call in pins], [126, 116])

    def test_import_narinfo_wait_stops_at_deadline_and_fails_closed(self):
        transport = FakeTransport()
        checked = []

        def public_check(path):
            checked.append(path)
            return False

        with (
            patch("time.sleep") as sleep,
            patch("time.monotonic", side_effect=[100, 101, 1900]),
            self.assertRaisesRegex(RuntimeError, "public narinfo"),
        ):
            publication.publish_paths(
                [PACKAGE],
                reviewed(),
                transport,
                public_check,
                apply=True,
            )
        self.assertEqual(checked, [PACKAGE, PACKAGE])
        self.assertEqual([call.args for call in sleep.call_args_list], [(10,)])
        self.assertEqual(transport.streamed, [PACKAGE])

    def test_import_narinfo_wait_propagates_validation_and_transport_errors(self):
        for error in (ValueError("invalid narinfo"), URLError("connection failed")):
            with self.subTest(error=error), patch("time.sleep") as sleep:
                transport = FakeTransport()

                def public_check(path, error=error):
                    raise error

                with self.assertRaises(type(error)) as raised:
                    publication.publish_paths(
                        [PACKAGE],
                        reviewed(),
                        transport,
                        public_check,
                        apply=True,
                    )
                self.assertIs(raised.exception, error)
                sleep.assert_not_called()
                self.assertEqual(transport.streamed, [PACKAGE])

    def test_present_but_not_public_output_is_held_without_readiness_wait(self):
        transport = FakeTransport(missing_public=())
        with patch("time.sleep") as sleep:
            result = publication.publish_paths(
                [PACKAGE],
                reviewed(),
                transport,
                lambda path: False,
                apply=True,
            )
        self.assertEqual(
            result["held"], [{"path": PACKAGE, "reason": "ct116_present_not_public"}]
        )
        self.assertEqual(transport.streamed, [])
        sleep.assert_not_called()

    def test_already_public_path_is_idempotent(self):
        transport = FakeTransport(missing_public=())
        policy = reviewed()
        for _ in range(2):
            result = publication.publish_paths(
                [PACKAGE], policy, transport, lambda path: True, apply=True
            )
            self.assertEqual(result["already_routes_reachable"], [PACKAGE])
        self.assertEqual(transport.streamed, [])
        self.assertEqual(transport.pinned, {(126, PACKAGE), (116, PACKAGE)})

    def test_public_claim_requires_every_requisite_not_only_root(self):
        transport = FakeTransport(requisites=(PACKAGE, OTHER), missing_public=())
        result = publication.publish_paths(
            [PACKAGE],
            reviewed(requisites=(PACKAGE, OTHER)),
            transport,
            lambda path: path == PACKAGE,
            apply=True,
        )
        self.assertEqual(
            result["held"],
            [{"path": PACKAGE, "reason": "ct116_present_not_public"}],
        )
        self.assertEqual(result["already_routes_reachable"], [])
        self.assertEqual(transport.pinned, set())

    def test_missing_builder_requisite_and_changed_closure_are_held(self):
        missing = FakeTransport(missing_builder=(PACKAGE,))
        result = publication.publish_paths(
            [PACKAGE], reviewed(), missing, lambda path: False, apply=True
        )
        self.assertEqual(
            result["held"], [{"path": PACKAGE, "reason": "missing_on_builder"}]
        )
        self.assertEqual(missing.streamed, [])
        changed = FakeTransport(requisites=(PACKAGE, OTHER))
        result = publication.publish_paths(
            [PACKAGE], reviewed(), changed, lambda path: False, apply=True
        )
        self.assertEqual(
            result["held"], [{"path": PACKAGE, "reason": "closure_changed"}]
        )
        self.assertEqual(changed.streamed, [])

    def test_reviewed_root_with_flagged_dependency_is_still_held(self):
        transport = FakeTransport(requisites=(PACKAGE, DENIED))
        result = publication.publish_paths(
            [PACKAGE],
            reviewed(requisites=(PACKAGE, DENIED)),
            transport,
            lambda path: False,
            apply=True,
        )
        self.assertEqual(
            result["held"], [{"path": PACKAGE, "reason": "known_review_trigger"}]
        )
        self.assertEqual(transport.streamed, [])

    def test_transfer_failure_or_public_validation_failure_cannot_report_success(self):
        failed = FakeTransport()
        failed.fail_stream = True
        with self.assertRaisesRegex(RuntimeError, "archive import failed"):
            publication.publish_paths(
                [PACKAGE], reviewed(), failed, lambda path: False, apply=True
            )
        unpublished = FakeTransport()
        with (
            patch("time.sleep"),
            patch("time.monotonic", side_effect=[100, 1900]),
            self.assertRaisesRegex(RuntimeError, "public narinfo"),
        ):
            publication.publish_paths(
                [PACKAGE], reviewed(), unpublished, lambda path: False, apply=True
            )

    def test_disk_guard_stops_before_transfer_and_limit_bounds_run(self):
        transport = FakeTransport()
        transport.fail_disk = True
        with self.assertRaisesRegex(RuntimeError, "disk guard"):
            publication.publish_paths(
                [PACKAGE], reviewed(), transport, lambda path: False, apply=True
            )
        self.assertEqual(transport.streamed, [])
        limited = publication.publish_paths(
            [PACKAGE], reviewed(), FakeTransport(), lambda path: False, limit=0
        )
        self.assertEqual(limited["held"], [{"path": PACKAGE, "reason": "run_limit"}])

    def test_unpinned_root_is_prioritized_before_already_public_root(self):
        transport = FakeTransport(missing_public=(OTHER,))
        policy = {
            "approved": {
                **reviewed(PACKAGE)["approved"],
                **reviewed(OTHER, requisites=(OTHER,))["approved"],
            },
            "denied": set(),
        }

        def run(ct, argv, input=None):
            transport.calls.append((ct, argv, input))
            if argv == ["python3", "-c", publication.LIST_PINNED_SCRIPT]:
                return (
                    f"{PACKAGE.removeprefix('/gnu/store/').split('-', 1)[0]}\n".encode()
                )
            if argv[1:3] == ["gc", "--requisites"]:
                return f"{argv[-1]}\n".encode()
            if argv[1:3] == ["archive", "--missing"]:
                assert input is not None
                requested = set(input.decode().splitlines())
                missing = set() if ct == 126 else {OTHER}
                values = sorted(requested & missing)
                return ("\n".join(values) + ("\n" if values else "")).encode()
            if argv[:2] == ["du", "-s"]:
                values = argv[argv.index("--") + 1 :]
                size = 1 if "--inodes" in argv else 1024
                return "".join(f"{size}\t{path}\n" for path in values).encode()
            raise AssertionError(f"unexpected container command: {ct} {argv}")

        transport.run = run
        result = publication.publish_paths(
            [PACKAGE, OTHER], policy, transport, lambda path: path == PACKAGE, limit=1
        )
        self.assertEqual(result["planned"], [OTHER])
        self.assertEqual(result["held"], [{"path": PACKAGE, "reason": "run_limit"}])

    def test_policy_rejects_bad_paths_and_duplicate_review_records(self):
        with self.assertRaises(ValueError):
            publication.parse_policy(
                b'{"schema":1,"approved":[],"denied":["/tmp/bad"]}'
            )
        value = json.loads(json.dumps({"schema": 1, "approved": [], "denied": []}))
        approved = json.loads(
            json.dumps(
                {
                    "path": PACKAGE,
                    "requisites_sha256": "a" * 64,
                    "reviewed_by": "reviewer",
                    "reviewed_at": "2026-10-14T21:00:00Z",
                    "license_basis": "Reviewed.",
                }
            )
        )
        value["approved"] = [approved, approved]
        with self.assertRaises(ValueError):
            publication.parse_policy(json.dumps(value).encode())
        approved["reviewed_at"] = "someday"
        value["approved"] = [approved]
        with self.assertRaises(ValueError):
            publication.parse_policy(json.dumps(value).encode())


class PublicationRootDirectoryTests(unittest.TestCase):
    def run_directory_program(self, root):
        guix = shutil.which("guix")
        if guix is None:
            self.skipTest("Guix is required for native root-directory checks")
        # Exercise the generated filesystem setup without opening a store
        # connection or registering any GC roots on the test machine.
        source = (
            publication._pin_source(PACKAGE).decode().split("(with-store store", 1)[0]
        )
        source = source.replace(
            '"/var/guix/gcroots/securityops-publication"', json.dumps(str(root))
        )
        script = root.parent / "prepare-root.scm"
        script.write_text("(umask #o077)\n" + source, encoding="utf-8")
        return subprocess.run(
            [guix, "repl", "-q", "--", str(script)],
            capture_output=True,
            timeout=30,
            check=False,
        )

    def test_root_directory_is_readable_despite_private_service_umask(self):
        for existing in (False, True):
            with (
                self.subTest(existing=existing),
                tempfile.TemporaryDirectory() as directory,
            ):
                root = Path(directory) / "roots"
                if existing:
                    root.mkdir(mode=0o700)
                result = self.run_directory_program(root)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(root.stat().st_mode & 0o7777, 0o755)

    def test_symlinked_root_directory_is_rejected_without_changing_target(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "roots"
            private = Path(directory) / "private"
            private.mkdir(mode=0o700)
            root.symlink_to(private, target_is_directory=True)
            result = self.run_directory_program(root)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(private.stat().st_mode & 0o7777, 0o700)
            self.assertTrue(root.is_symlink())


class PublicationHostTests(unittest.TestCase):
    def run_pin_programs(self, *, already_public, exit_code=0, source=None):
        with tempfile.TemporaryDirectory() as directory:
            guix = Path(directory) / "guix"
            guix.write_text(
                "#!/usr/bin/env python3\n"
                "import json, pathlib, stat, sys\n"
                "assert sys.argv[1:4] == ['repl', '-q', '--']\n"
                "script = pathlib.Path(sys.argv[4])\n"
                "source = script.read_text()\n"
                "print(json.dumps({'source': source, 'path': str(script),\n"
                "    'mode': stat.S_IMODE(script.stat().st_mode),\n"
                "    'directory_mode': stat.S_IMODE(script.parent.stat().st_mode)}))\n"
                f"sys.exit({exit_code})\n",
                encoding="utf-8",
            )
            guix.chmod(0o700)
            transport = FakeTransport(
                missing_public=() if already_public else (PACKAGE,)
            )
            with patch.object(publication, "GUIX", str(guix)):
                publication.publish_paths(
                    [PACKAGE], reviewed(), transport, lambda path: True, apply=True
                )
            calls = [
                call
                for call in transport.calls
                if isinstance(call[0], int)
                and call[2]
                and b"add-indirect-root" in call[2]
            ]
            self.assertEqual([call[0] for call in calls], [126, 116])
            results = []
            for _, command, script in calls:
                # A socket can be read through fd 0 but cannot be reopened as
                # /dev/stdin, like the inherited pipe in the unprivileged CT.
                reader, writer = socket.socketpair()
                with reader, writer:
                    writer.sendall(script if source is None else source)
                    writer.shutdown(socket.SHUT_WR)
                    results.append(
                        subprocess.run(
                            command,
                            stdin=reader.fileno(),
                            capture_output=True,
                            timeout=10,
                            check=False,
                        )
                    )
            return results

    def test_pin_scripts_use_private_files_when_stdin_cannot_be_reopened(self):
        for already_public in (False, True):
            with self.subTest(already_public=already_public):
                for result in self.run_pin_programs(already_public=already_public):
                    self.assertEqual(result.returncode, 0, result.stderr)
                    record = json.loads(result.stdout)
                    self.assertIn(PACKAGE, record["source"])
                    self.assertEqual(record["mode"], 0o600)
                    self.assertEqual(record["directory_mode"], 0o700)
                    self.assertFalse(Path(record["path"]).parent.exists())

    def test_pin_script_failure_propagates_and_removes_temporary_files(self):
        for result in self.run_pin_programs(already_public=False, exit_code=7):
            self.assertEqual(result.returncode, 7, result.stderr)
            record = json.loads(result.stdout)
            self.assertFalse(Path(record["path"]).parent.exists())

    def test_pin_script_input_is_bounded_before_guix_runs(self):
        for result in self.run_pin_programs(already_public=False, source=b"x" * 65537):
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(b"pin script exceeds", result.stderr)
            self.assertEqual(result.stdout, b"")

    def test_host_capacity_reads_destination_inode_availability(self):
        transport = publication.HostTransport()
        pool = subprocess.CompletedProcess(
            args=[], returncode=0, stdout=b"107374182400 1.00 1.00\n", stderr=b""
        )
        with (
            patch.object(publication.Path, "exists", return_value=False),
            patch.object(publication.subprocess, "run", return_value=pool),
            patch.object(
                transport, "run", return_value=b"Avail IFree\n21474836480 50000\n"
            ) as remote,
            self.assertRaisesRegex(RuntimeError, "CT116 inode"),
        ):
            transport.ensure_capacity(1024, 1)
        remote.assert_called_once_with(
            116, ["df", "-B1", "--output=avail,iavail", "/gnu/store"]
        )

    def test_inventory_reader_distinguishes_missing_from_present_and_symlink(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "system.json"

            def read(candidate):
                return subprocess.run(
                    [sys.executable, "-c", publication.READ_INVENTORY, str(candidate)],
                    capture_output=True,
                    check=False,
                )

            missing = read(path)
            self.assertEqual((missing.returncode, missing.stdout), (0, b"M"))
            path.write_bytes(b"{}")
            present = read(path)
            self.assertEqual((present.returncode, present.stdout), (0, b"P{}"))
            link = Path(directory) / "link.json"
            link.symlink_to(path)
            self.assertNotEqual(read(link).returncode, 0)

    def test_service_runs_from_the_small_host_install_not_a_missing_checkout(self):
        service = MODULE.with_name("securityops-publication.service").read_text()
        self.assertIn("WorkingDirectory=/opt/farm-publication", service)
        self.assertIn(
            "ExecStart=/usr/bin/python3 /opt/farm-publication/publication/publish.py",
            service,
        )

    def test_collects_only_fixed_completed_evaluation_and_fresh_inventory(self):
        class SourceTransport:
            def __init__(self):
                self.calls = []

            def run(self, ct, argv, input=None):
                self.calls.append((ct, argv, input))
                if "psql" in argv:
                    return csv_row(
                        "channel.package.x86_64-linux", 0, 0, PACKAGE
                    ).encode()
                if argv[-1].endswith("system.json"):
                    return b"P" + json.dumps(manifest("system")).encode()
                if argv[-1].endswith("home.json"):
                    return b"P" + json.dumps(manifest("home", [entry(HOME)])).encode()
                raise AssertionError(argv)

        transport = SourceTransport()
        selected, held, evaluation = publication.collect_targets(
            transport, NOW, include_workstation=True
        )
        self.assertEqual(selected, [PACKAGE, HOME])
        self.assertEqual(held, [])
        self.assertEqual(evaluation, 42)
        self.assertTrue(all(call[0] == 126 for call in transport.calls))
        self.assertEqual(len(transport.calls), 3)
        sql = transport.calls[0][1][-1]
        self.assertIn("status = 0", sql)
        self.assertIn("specification = 'securityops'", sql)
        self.assertIn("x86_64-linux", sql)

    def test_missing_or_stale_workstation_inventory_does_not_block_channel(self):
        class SourceTransport:
            def run(self, ct, argv, input=None):
                if "psql" in argv:
                    return csv_row(
                        "channel.package.x86_64-linux", 0, 0, PACKAGE
                    ).encode()
                if argv[-1].endswith("system.json"):
                    return b"M"
                stale = manifest("home", [entry(HOME)])
                stale["generated_at"] = "2026-10-12T21:00:00Z"
                stale["heartbeat_at"] = "2026-10-12T21:01:00Z"
                return b"P" + json.dumps(stale).encode()

        selected, held, evaluation = publication.collect_targets(
            SourceTransport(), NOW, include_workstation=True
        )
        self.assertEqual(selected, [PACKAGE])
        self.assertEqual(evaluation, 42)
        self.assertEqual(
            held,
            [
                {"source": "system", "reason": "missing_inventory"},
                {"source": "home", "reason": "stale_inventory"},
            ],
        )

    def test_malformed_present_inventory_still_fails_closed(self):
        class SourceTransport:
            def run(self, ct, argv, input=None):
                if "psql" in argv:
                    return csv_row(
                        "channel.package.x86_64-linux", 0, 0, PACKAGE
                    ).encode()
                return b"Pnot-json"

        with self.assertRaises(ValueError):
            publication.collect_targets(
                SourceTransport(), NOW, include_workstation=True
            )

    def test_default_publication_never_reads_workstation_inventories(self):
        class ChannelOnlyTransport:
            def run(self, ct, argv, input=None):
                if "psql" in argv:
                    return (
                        csv_row("channel.package.x86_64-linux", 0, 0, PACKAGE)
                        + csv_row("channel.failed.x86_64-linux", 1, 1, FAILED)
                    ).encode()
                raise AssertionError(
                    "public channel run attempted private inventory access"
                )

        selected, held, evaluation = publication.collect_targets(
            ChannelOnlyTransport(), NOW
        )
        self.assertEqual(selected, [PACKAGE])
        self.assertEqual(evaluation, 42)
        self.assertEqual(held, [{"path": FAILED, "reason": "unsuccessful_job"}])

    def test_public_narinfo_must_name_exact_output_and_have_signature(self):
        valid = (
            f"StorePath: {PACKAGE}\n"
            "NarHash: sha256:" + "a" * 52 + "\n"
            "URL: nar/zstd/fixture\nSignature: 1;guix-substitute;abc\n"
        )
        self.assertTrue(publication.validate_narinfo(PACKAGE, valid))
        self.assertTrue(
            publication.validate_narinfo(
                PACKAGE,
                valid.replace("nar/zstd/fixture", "nar/zstd/libstdc%2B%2B-14.3.0"),
            )
        )
        with self.assertRaises(ValueError):
            publication.validate_narinfo(PACKAGE, valid.replace(PACKAGE, HOME))
        with self.assertRaises(ValueError):
            publication.validate_narinfo(
                PACKAGE, valid.replace("Signature:", "Unsigned:")
            )
        with self.assertRaises(ValueError):
            publication.validate_narinfo(
                PACKAGE, valid.replace("nar/zstd/fixture", "../bad")
            )
        with self.assertRaises(ValueError):
            publication.validate_narinfo(
                PACKAGE,
                valid.replace("nar/zstd/fixture", "nar/zstd/%2E%2E%2Fsecret"),
            )

    def test_404_is_not_public_and_other_http_failures_are_errors(self):
        class FakeOpener:
            def __init__(self):
                self.error: HTTPError = HTTPError(
                    "https://example.test", 404, "missing", Message(), None
                )

            def open(self, request, timeout):
                raise self.error

        opener = FakeOpener()
        with patch.object(publication, "build_opener", return_value=opener):
            opener.error = HTTPError(
                "https://example.test", 404, "missing", Message(), None
            )
            self.assertFalse(publication.check_public_output(PACKAGE))
            opener.error = HTTPError(
                "https://example.test", 503, "error", Message(), None
            )
            with patch("time.sleep") as sleep, self.assertRaises(HTTPError):
                publication.check_public_output(PACKAGE)
            self.assertEqual([call.args for call in sleep.call_args_list], [(5,)] * 3)

    def test_oversized_public_narinfo_is_rejected(self):
        class Response:
            status = 200

            def __enter__(self):
                return self

            def __exit__(self, *args):
                return False

            def read(self, count):
                return b"x" * count

        class FakeOpener:
            def open(self, request, timeout):
                return Response()

        with (
            patch.object(publication, "build_opener", return_value=FakeOpener()),
            self.assertRaisesRegex(ValueError, "exceeds 64 KiB"),
        ):
            publication.check_public_output(PACKAGE)

    def test_advertised_public_nar_must_be_reachable_by_get(self):
        narinfo = (
            f"StorePath: {PACKAGE}\nNarHash: sha256:{'a' * 52}\n"
            "URL: nar/zstd/fixture\nSignature: 1;guix-substitute;abc\n"
        ).encode()

        class Response:
            status = 200

            def __enter__(self):
                return self

            def __exit__(self, *args):
                return False

            def read(self, count):
                return narinfo[:count]

        class FakeOpener:
            def open(self, request, timeout):
                if request.full_url.endswith(".narinfo"):
                    return Response()
                self.requested_nar = request.full_url
                raise HTTPError(request.full_url, 404, "missing NAR", Message(), None)

        opener = FakeOpener()
        with (
            patch.object(publication, "build_opener", return_value=opener),
            self.assertRaises(ValueError),
        ):
            publication.check_public_output(PACKAGE)
        self.assertEqual(
            opener.requested_nar,
            "https://substitutes.securityops.co/nar/zstd/fixture",
        )

    def test_capacity_check_rejects_full_thin_pool_and_missing_reserve(self):
        with self.assertRaisesRegex(RuntimeError, "thin pool"):
            publication.check_capacity(
                "107374182400 80.01 1.00", 100 * 1024**3, 1024, 200000, 1
            )
        with self.assertRaisesRegex(RuntimeError, "thin pool"):
            publication.check_capacity(
                "107374182400 1.00 85.01", 100 * 1024**3, 1024, 200000, 1
            )
        with self.assertRaisesRegex(RuntimeError, "thin pool"):
            publication.check_capacity(
                "107374182400 79.00 1.00", 100 * 1024**3, 2 * 1024**3, 200000, 1
            )
        with self.assertRaisesRegex(RuntimeError, "CT116 space"):
            publication.check_capacity("107374182400 1.00 1.00", 1024, 1024, 200000, 1)
        with self.assertRaisesRegex(RuntimeError, "CT116 inode"):
            publication.check_capacity(
                "107374182400 1.00 1.00", 20 * 1024**3, 1024, 50000, 100000
            )
        publication.check_capacity(
            "107374182400 1.00 1.00", 20 * 1024**3, 1024, 200000, 1
        )

    def test_binary_archive_is_piped_between_exact_pct_containers(self):
        with tempfile.TemporaryDirectory() as directory:
            script = Path(directory) / "pct"
            destination = Path(directory) / "received"
            script.write_text(
                "#!/usr/bin/env python3\n"
                "import pathlib, sys\n"
                "ct, command = sys.argv[2], sys.argv[4:]\n"
                "if ct == '126' and command[1:3] == ['archive', '--export'] "
                "and '--max-jobs=0' in command and '--no-substitutes' in command:\n"
                "    sys.stdout.buffer.write(bytes([0, 255, 10, 128]))\n"
                "elif ct == '116' and command[1:3] == ['archive', '--import']:\n"
                f"    pathlib.Path({str(destination)!r}).write_bytes(sys.stdin.buffer.read())\n"
                "else:\n"
                "    raise SystemExit(9)\n",
                encoding="utf-8",
            )
            os.chmod(script, 0o700)
            transport = publication.HostTransport(pct=str(script))
            transport.stream_archive(PACKAGE)
            self.assertEqual(destination.read_bytes(), bytes([0, 255, 10, 128]))

    def test_binary_archive_stream_stops_at_preflight_byte_limit(self):
        with tempfile.TemporaryDirectory() as directory:
            script = Path(directory) / "pct"
            destination = Path(directory) / "received"
            script.write_text(
                "#!/usr/bin/env python3\n"
                "import pathlib, sys\n"
                "if sys.argv[2] == '126':\n"
                "    sys.stdout.buffer.write(b'x' * 1024)\n"
                "else:\n"
                f"    pathlib.Path({str(destination)!r}).write_bytes(sys.stdin.buffer.read())\n",
                encoding="utf-8",
            )
            os.chmod(script, 0o700)
            with self.assertRaisesRegex(RuntimeError, "byte guard"):
                publication.HostTransport(pct=str(script)).stream_archive(
                    PACKAGE, max_bytes=100
                )
            self.assertFalse(destination.exists() and destination.stat().st_size > 100)

    def test_failed_binary_import_is_reported_and_never_pinned(self):
        with tempfile.TemporaryDirectory() as directory:
            script = Path(directory) / "pct"
            script.write_text(
                "#!/usr/bin/env python3\n"
                "import sys\n"
                "if sys.argv[2] == '126':\n"
                "    sys.stdout.buffer.write(b'archive')\n"
                "else:\n"
                "    raise SystemExit(7)\n",
                encoding="utf-8",
            )
            os.chmod(script, 0o700)
            with self.assertRaisesRegex(RuntimeError, "import=7"):
                publication.HostTransport(pct=str(script)).stream_archive(PACKAGE)

    def test_early_importer_exit_reports_status_instead_of_broken_pipe(self):
        with tempfile.TemporaryDirectory() as directory:
            script = Path(directory) / "pct"
            script.write_text(
                "#!/usr/bin/env python3\n"
                "import os, sys\n"
                "if sys.argv[2] == '126':\n"
                "    for _ in range(4): os.write(1, b'x' * 1048576)\n"
                "else:\n"
                "    raise SystemExit(7)\n",
                encoding="utf-8",
            )
            os.chmod(script, 0o700)
            with self.assertRaisesRegex(RuntimeError, "import=7"):
                publication.HostTransport(pct=str(script)).stream_archive(PACKAGE)

    def test_guix_root_script_runs_as_file_and_validates_path(self):
        script = publication._pin_source(PACKAGE)
        self.assertIn(b"add-indirect-root", script)
        with self.assertRaises(ValueError):
            publication._pin_source(
                "/gnu/store/" + "a" * 32 + '-bad" (system "touch /tmp/x")'
            )
        transport = FakeTransport(missing_public=())
        publication.publish_paths(
            [PACKAGE], reviewed(), transport, lambda path: True, apply=True
        )
        self.assertEqual(transport.pinned, {(126, PACKAGE), (116, PACKAGE)})

    def test_main_without_apply_reports_dry_run_and_never_streams(self):
        transport = FakeTransport()
        output = io.StringIO()
        with (
            patch.object(publication, "HostTransport", return_value=transport),
            patch.object(publication, "_read_policy", return_value=reviewed()),
            patch.object(
                publication, "collect_targets", return_value=([PACKAGE], [], 42)
            ),
            patch.object(publication, "check_both_publishers", return_value=False),
            redirect_stdout(output),
        ):
            self.assertEqual(publication.main([]), 0)
        report = json.loads(output.getvalue())
        self.assertTrue(report["dry_run"])
        self.assertFalse(report["include_workstation"])
        self.assertEqual(report["planned"], [PACKAGE])
        self.assertEqual(transport.streamed, [])


if __name__ == "__main__":
    unittest.main()
