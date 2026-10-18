"""Run as cuirass in the private builder; verify real evaluation log writes."""

import gzip
import os
import stat
import tempfile
from pathlib import Path

directory = Path("/var/log/cuirass")
metadata = directory.stat()
assert metadata.st_uid == os.geteuid(), "evaluation logs are not owned by cuirass"
assert stat.S_IMODE(metadata.st_mode) == 0o700, "evaluation logs are not private"

# Exercise the same child directory and gzip-file operations as Cuirass without
# registering an evaluation, touching its database, or starting package builds.
with tempfile.TemporaryDirectory(prefix="write-check-", dir=directory) as temporary:
    path = Path(temporary) / "evaluation.gz"
    with gzip.open(path, "wt", encoding="ascii") as stream:
        stream.write("evaluation-log-write-check\n")
    with gzip.open(path, "rt", encoding="ascii") as stream:
        assert stream.read() == "evaluation-log-write-check\n"

print("PASS: private evaluation directory supports gzip log writes as cuirass")
