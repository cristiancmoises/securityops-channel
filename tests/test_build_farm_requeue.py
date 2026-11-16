"""Exercise the Cuirass stalled-build requeue wrapper."""

import json
import os
import sqlite3
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "etc/build-farm/requeue-stalled-builds"


class RequeueStalledBuildsTest(unittest.TestCase):
    def run_script(
        self,
        directory,
        *,
        psql_exit=0,
        enabled=True,
        units=(),
        listing_exit=0,
        pending="2",
        started="0",
        database=None,
    ):
        fake_runuser = directory / "runuser"
        fake_psql = directory / "psql"
        fake_systemctl = directory / "systemctl"
        marker = directory / "requeue-last"
        calls = directory / "restart-calls"

        fake_runuser.write_text(
            "#!/bin/sh\n"
            'test "$1" = -u || exit 91\n'
            'test "$2" = postgres || exit 92\n'
            'test "$3" = -- || exit 93\n'
            "shift 3\n"
            'exec "$@"\n',
            encoding="utf-8",
        )
        fake_psql.write_text(
            f"#!{sys.executable}\n"
            "import os, sqlite3, sys\n"
            "if int(os.environ['FAKE_PSQL_EXIT']):\n"
            "    sys.exit(int(os.environ['FAKE_PSQL_EXIT']))\n"
            "query = sys.argv[-1]\n"
            "if os.environ['FIXTURE_DB']:\n"
            "    with sqlite3.connect('file:' + os.environ['FIXTURE_DB'] + '?mode=ro',\n"
            "                         uri=True) as database:\n"
            "        print(database.execute(query).fetchone()[0])\n"
            "elif 'status = -2' in query:\n"
            "    print(os.environ['PENDING_COUNT'])\n"
            "elif 'status = -1' in query:\n"
            "    print(os.environ['STARTED_COUNT'])\n"
            "else:\n"
            "    sys.exit(94)\n",
            encoding="utf-8",
        )
        fake_systemctl.write_text(
            f"#!{sys.executable}\n"
            "import fnmatch, json, os, sys\n"
            "args = sys.argv[1:]\n"
            "if args[0] == 'is-enabled':\n"
            "    sys.exit(int(os.environ['ENABLED_EXIT']))\n"
            "if args[0] == 'list-units':\n"
            "    if int(os.environ['LISTING_EXIT']):\n"
            "        print('incomplete unit inspection')\n"
            "        sys.exit(int(os.environ['LISTING_EXIT']))\n"
            "    states = next((a.split('=', 1)[1].split(',') for a in args\n"
            "                   if a.startswith('--state=')), None)\n"
            "    patterns = [a for a in args if a.endswith('.service')]\n"
            "    for name, active, sub in json.loads(os.environ['UNITS']):\n"
            "        if states and active not in states and sub not in states:\n"
            "            continue\n"
            "        if patterns and not any(fnmatch.fnmatchcase(name, p)\n"
            "                                for p in patterns):\n"
            "            continue\n"
            "        print(name, 'loaded', active, sub, 'worker fixture')\n"
            "    sys.exit(0)\n"
            "if args[0] != 'restart':\n"
            "    sys.exit(95)\n"
            f"with open({str(calls)!r}, 'w') as output:\n"
            "    output.write(' '.join(args) + '\\n')\n",
            encoding="utf-8",
        )
        for command in (fake_runuser, fake_psql, fake_systemctl):
            command.chmod(0o755)

        environment = {
            **os.environ,
            "RUNUSER": str(fake_runuser),
            "PSQL": str(fake_psql),
            "SYSTEMCTL": str(fake_systemctl),
            "MARKER": str(marker),
            "FAKE_PSQL_EXIT": str(psql_exit),
            "ENABLED_EXIT": "0" if enabled else "1",
            "UNITS": json.dumps(units),
            "LISTING_EXIT": str(listing_exit),
            "PENDING_COUNT": pending,
            "STARTED_COUNT": started,
            "FIXTURE_DB": str(database) if database is not None else "",
        }
        result = subprocess.run(
            ["/bin/sh", str(SCRIPT)],
            env=environment,
            capture_output=True,
            text=True,
            check=False,
        )
        return result, calls

    def database_fixture(self, directory):
        path = directory / "cuirass.sqlite"
        with sqlite3.connect(path) as database:
            database.executescript(
                """
                CREATE TABLE evaluations
                  (id INTEGER, specification TEXT, status INTEGER);
                CREATE TABLE jobs (evaluation INTEGER, build INTEGER);
                CREATE TABLE builds (id INTEGER, status INTEGER);
                CREATE TABLE builddependencies (source INTEGER, target INTEGER);
                INSERT INTO evaluations VALUES (10, 'securityops', 0),
                                               (11, 'securityops', 0),
                                               (12, 'securityops', 1),
                                               (20, 'other', 0), (21, 'other', 0);
                INSERT INTO jobs VALUES (10, 101), (11, 102), (12, 103),
                                        (20, 201), (21, 202);
                INSERT INTO builds VALUES (101, -2), (102, 0), (103, -2),
                                          (201, -2), (202, 0), (301, 0),
                                          (302, 0), (303, 0);
                INSERT INTO builddependencies VALUES (102, 301), (301, 302),
                                                     (202, 301), (202, 303);
                """
            )
        return path

    def test_only_obsolete_or_incomplete_evaluation_builds_do_not_trigger_restart(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            database = self.database_fixture(directory)
            result, calls = self.run_script(directory, database=database)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("pending(scheduled)=0 started=0", result.stdout)
            self.assertFalse(calls.exists())
            self.assertFalse((directory / "requeue-last").exists())

    def test_latest_each_jobset_and_transitive_shared_dependencies_are_counted(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            database = self.database_fixture(directory)
            with sqlite3.connect(database) as connection:
                connection.execute(
                    "UPDATE builds SET status = -2 WHERE id IN (102, 202, 301, 302)"
                )
                connection.execute("UPDATE builds SET status = -1 WHERE id = 101")
            result, calls = self.run_script(directory, database=database)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("pending(scheduled)=4 started=0", result.stdout)
            self.assertTrue(calls.exists())

    def test_started_dependency_of_current_job_prevents_restart(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            database = self.database_fixture(directory)
            with sqlite3.connect(database) as connection:
                connection.execute(
                    "UPDATE builds SET status = -2 WHERE id IN (102, 202)"
                )
                connection.execute("UPDATE builds SET status = -1 WHERE id = 302")
            result, calls = self.run_script(directory, database=database)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("pending(scheduled)=2 started=1", result.stdout)
            self.assertFalse(calls.exists())
            self.assertFalse((directory / "requeue-last").exists())

    def test_running_and_activating_external_workers_prevent_restart(self):
        for name in (
            "securityops-medium-retry-20261115.service",
            "securityops-torbrowser-source-20261116.service",
        ):
            for active, sub in (("active", "running"), ("activating", "start")):
                with (
                    self.subTest(name=name, state=(active, sub)),
                    tempfile.TemporaryDirectory() as temporary,
                ):
                    directory = Path(temporary)
                    result, calls = self.run_script(
                        directory, units=[(name, active, sub)]
                    )
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertIn("external Guix build worker", result.stdout)
                    self.assertFalse(calls.exists())
                    self.assertFalse((directory / "requeue-last").exists())

    def test_completed_workers_and_unrelated_services_do_not_block_recovery(self):
        with tempfile.TemporaryDirectory() as temporary:
            result, calls = self.run_script(
                Path(temporary),
                units=[
                    ("securityops-medium-retry-old.service", "inactive", "dead"),
                    ("securityops-torbrowser-source-old.service", "active", "exited"),
                    ("securityops-other-retry-old.service", "failed", "failed"),
                    ("securityops-publication.service", "active", "running"),
                ],
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(
                calls.read_text(), "restart securityops-cuirass-register.service\n"
            )

    def test_failed_worker_inspection_defers_without_a_restart_or_marker(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            result, calls = self.run_script(directory, listing_exit=23)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("cannot inspect", result.stderr)
            self.assertFalse(calls.exists())
            self.assertFalse((directory / "requeue-last").exists())

    def test_active_worker_preserves_an_existing_debounce_marker(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            marker = directory / "requeue-last"
            marker.write_text("1\n")
            result, calls = self.run_script(
                directory,
                units=[("securityops-medium-retry-now.service", "active", "running")],
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(marker.read_text(), "1\n")
            self.assertFalse(calls.exists())

    def test_recent_restart_remains_debounced(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            marker = directory / "requeue-last"
            original = str(int(time.time())) + "\n"
            marker.write_text(original)
            result, calls = self.run_script(directory)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("debounced", result.stdout)
            self.assertEqual(marker.read_text(), original)
            self.assertFalse(calls.exists())

    def test_no_pending_or_native_build_in_progress_prevents_restart(self):
        for pending, started in (("0", "0"), ("2", "1")):
            with (
                self.subTest(pending=pending, started=started),
                tempfile.TemporaryDirectory() as temporary,
            ):
                directory = Path(temporary)
                result, calls = self.run_script(
                    directory, pending=pending, started=started
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertFalse(calls.exists())
                self.assertFalse((directory / "requeue-last").exists())

    def test_invalid_database_counts_fail_closed(self):
        for pending, started in (("bad", "0"), ("2", "bad"), ("", "0"), ("2", "-1")):
            with (
                self.subTest(pending=pending, started=started),
                tempfile.TemporaryDirectory() as temporary,
            ):
                directory = Path(temporary)
                result, calls = self.run_script(
                    directory, pending=pending, started=started
                )
                self.assertEqual(result.returncode, 1)
                self.assertFalse(calls.exists())
                self.assertFalse((directory / "requeue-last").exists())

    def test_queries_postgres_and_restarts_stalled_register(self):
        with tempfile.TemporaryDirectory() as temporary:
            result, calls = self.run_script(Path(temporary))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("pending(scheduled)=2 started=0", result.stdout)
            self.assertEqual(
                calls.read_text(encoding="utf-8"),
                "restart securityops-cuirass-register.service\n",
            )

    def test_disabled_registration_stays_paused(self):
        with tempfile.TemporaryDirectory() as temporary:
            result, calls = self.run_script(
                Path(temporary), enabled=False, psql_exit=17
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("registration disabled", result.stdout)
            self.assertFalse(calls.exists())

    def test_database_error_is_not_mistaken_for_empty_queue(self):
        with tempfile.TemporaryDirectory() as temporary:
            result, calls = self.run_script(Path(temporary), psql_exit=17)
            self.assertEqual(result.returncode, 17)
            self.assertNotIn("pending(scheduled)=0", result.stdout)
            self.assertFalse(calls.exists())


if __name__ == "__main__":
    unittest.main()
