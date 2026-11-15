"""Exercise the Cuirass stalled-build requeue wrapper."""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "etc/build-farm/requeue-stalled-builds"


class RequeueStalledBuildsTest(unittest.TestCase):
    def run_script(self, directory, *, psql_exit=0):
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
            "#!/bin/sh\n"
            'test "${FAKE_PSQL_EXIT:-0}" -eq 0 || exit "${FAKE_PSQL_EXIT}"\n'
            'case "$*" in\n'
            "  *'status = -2'*) printf '2\\n' ;;\n"
            "  *'status = -1'*) printf '0\\n' ;;\n"
            "  *) exit 94 ;;\n"
            "esac\n",
            encoding="utf-8",
        )
        fake_systemctl.write_text(
            f'#!/bin/sh\nprintf "%s\\n" "$*" > "{calls}"\n',
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
        }
        result = subprocess.run(
            ["/bin/sh", str(SCRIPT)],
            env=environment,
            capture_output=True,
            text=True,
            check=False,
        )
        return result, calls

    def test_queries_postgres_and_restarts_stalled_register(self):
        with tempfile.TemporaryDirectory() as temporary:
            result, calls = self.run_script(Path(temporary))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("pending(scheduled)=2 started=0", result.stdout)
            self.assertEqual(
                calls.read_text(encoding="utf-8"),
                "restart securityops-cuirass-register.service\n",
            )

    def test_database_error_is_not_mistaken_for_empty_queue(self):
        with tempfile.TemporaryDirectory() as temporary:
            result, calls = self.run_script(Path(temporary), psql_exit=17)
            self.assertEqual(result.returncode, 17)
            self.assertNotIn("pending(scheduled)=0", result.stdout)
            self.assertFalse(calls.exists())


if __name__ == "__main__":
    unittest.main()
