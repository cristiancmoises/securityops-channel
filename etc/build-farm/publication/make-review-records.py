"""Draft review records for exact outputs using their live Guix requisites.

Usage: run on CT126 where the build outputs live:

    python3 make-review-records.py /gnu/store/HASH-name [...] [--owner]

Each path argument must be an exact store path.  The script computes the
sorted `guix gc --requisites` closure, prints one review record per path, and
appends them to a file you choose (default stdout) for insertion into
`reviewed-closures.json`.  It never modifies the policy file itself.
"""

import argparse
import hashlib
import json
import re
import subprocess
import sys
from datetime import datetime, timezone

STORE_PATH = re.compile(r"^/gnu/store/[a-z0-9]{32}-[_A-Za-z0-9][_A-Za-z0-9+.?~-]*$")
OWNER_TOKEN = "owner-approved-public-redistribution"
GUIX = "/var/guix/profiles/per-user/root/current-guix/bin/guix"


def requisites(path):
    result = subprocess.run(
        [GUIX, "gc", "--requisites", path],
        capture_output=True,
        text=True,
        check=False,
        timeout=1800,
    )
    if result.returncode:
        raise RuntimeError(f"guix gc failed for {path}: {result.stderr[-2000:]}")
    paths = result.stdout.splitlines()
    if path not in paths or len(paths) != len(set(paths)):
        raise RuntimeError(f"invalid requisites for {path}")
    for item in paths:
        if not STORE_PATH.fullmatch(item):
            raise RuntimeError(f"invalid requisite path {item}")
    return sorted(paths)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="+")
    parser.add_argument(
        "--owner",
        action="store_true",
        help=(
            "include the owner-approved public redistribution token in the "
            "license_basis (only for outputs the operator explicitly approved)"
        ),
    )
    parser.add_argument("--out", help="append records to this JSON file")
    args = parser.parse_args(argv)
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    records = []
    for path in args.paths:
        if not STORE_PATH.fullmatch(path) or path.endswith(".drv"):
            raise ValueError(f"invalid exact store path: {path}")
        closure = requisites(path)
        digest = hashlib.sha256(("\n".join(closure) + "\n").encode()).hexdigest()
        basis = (
            "Operator-approved public redistribution under the terms of the "
            "output and its reviewed closure. "
            + OWNER_TOKEN
            if args.owner
            else (
                "Source and requisite redistribution terms reviewed by the "
                "operator for public farm publication."
            )
        )
        records.append(
            {
                "path": path,
                "requisites_sha256": digest,
                "reviewed_by": "operator",
                "reviewed_at": now,
                "license_basis": basis,
            }
        )
    payload = json.dumps(records, indent=1)
    if args.out:
        with open(args.out, "a", encoding="utf-8") as stream:
            stream.write(payload + "\n")
        print(f"appended {len(records)} records to {args.out}")
    else:
        print(payload)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
        print(f"make-review-records failed: {error}", file=sys.stderr)
        sys.exit(1)
