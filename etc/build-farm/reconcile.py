#!/usr/bin/env python3
"""Check that a Cuirass evaluation contains every channel package and version.

The inventory has owner, exported symbol, package name, version, and home page
columns.  Cuirass /api/jobs gives job names and build IDs; /build/<id> gives
the derivation's nixname, which is needed to detect stale package versions.
"""

import argparse
import json
import sys
from collections import Counter
from pathlib import Path
from urllib.parse import quote, urlsplit
from urllib.request import urlopen


def _inventory(text):
    packages = {}
    duplicates = []
    for number, line in enumerate(text.splitlines(), 1):
        if not line:
            continue
        fields = line.split("\t")
        if len(fields) != 5 or any(not field for field in fields[:4]):
            raise ValueError(f"invalid inventory row {number}")
        owner, symbol, name, version, _ = fields
        export = (owner, symbol)
        if export in packages:
            duplicates.append(f"{owner}.{symbol}@{version}")
        else:
            packages[export] = (name, version)
    if not packages:
        raise ValueError("inventory is empty")
    return packages, sorted(duplicates)


def reconcile(inventory_text, jobs_json, builds, system):
    """Return a precise report; queued and failed builds both count as jobs."""
    packages, inventory_duplicates = _inventory(inventory_text)
    try:
        jobs = json.loads(jobs_json)
    except json.JSONDecodeError as error:
        raise ValueError("invalid Cuirass jobs JSON") from error
    if not isinstance(jobs, list) or any(
        not isinstance(job, dict)
        or not isinstance(job.get("name"), str)
        or not isinstance(job.get("build"), int)
        for job in jobs
    ):
        raise ValueError("invalid Cuirass jobs response")
    if not isinstance(builds, dict) or not system:
        raise ValueError("invalid build metadata or system")

    counts = Counter(job["name"] for job in jobs)
    duplicates = sorted(name for name, count in counts.items() if count != 1)
    expected = {
        f"{owner}.{symbol}.{system}": (f"{owner}.{symbol}@{version}", name, version)
        for (owner, symbol), (name, version) in packages.items()
    }
    actual = {job["name"]: job for job in jobs}
    missing = sorted(
        identity
        for job_name, (identity, _, _) in expected.items()
        if job_name not in actual
    )
    extra = sorted(name for name in actual if name not in expected)
    version_mismatch = []
    metadata_mismatch = []
    for job_name, (identity, name, version) in expected.items():
        job = actual.get(job_name)
        if job is None:
            continue
        build = builds.get(job["build"])
        if (
            not isinstance(build, dict)
            or build.get("id") != job["build"]
            or build.get("job") != job_name
            or build.get("system") != system
        ):
            metadata_mismatch.append(identity)
        elif build.get("nixname") != f"{name}-{version}":
            version_mismatch.append(identity)

    report = {
        "inventory_count": len(packages),
        "job_count": len(jobs),
        "missing": missing,
        "duplicates": duplicates,
        "inventory_duplicates": inventory_duplicates,
        "extra": extra,
        "version_mismatch": sorted(version_mismatch),
        "metadata_mismatch": sorted(metadata_mismatch),
    }
    report["ok"] = not any(
        report[key]
        for key in (
            "missing",
            "duplicates",
            "inventory_duplicates",
            "extra",
            "version_mismatch",
            "metadata_mismatch",
        )
    )
    return report


def _loopback_url(value):
    parsed = urlsplit(value)
    if parsed.scheme != "http" or parsed.hostname not in {
        "127.0.0.1",
        "::1",
        "localhost",
    }:
        raise ValueError("Cuirass API must be on loopback HTTP")
    if parsed.path or parsed.query or parsed.fragment or not parsed.port:
        raise ValueError("Cuirass API URL must contain only host and port")
    return value.rstrip("/")


def _fetch(url):
    with urlopen(url, timeout=15) as response:
        return response.read().decode("utf-8")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--inventory", type=Path, required=True)
    parser.add_argument("--evaluation", type=int)
    parser.add_argument("--base-url", default="http://127.0.0.1:8081")
    parser.add_argument("--jobs-json", type=Path)
    parser.add_argument("--builds-json", type=Path)
    args = parser.parse_args(argv)
    if args.jobs_json:
        if not args.builds_json:
            parser.error("--builds-json is required with --jobs-json")
        jobs_json = args.jobs_json.read_text(encoding="utf-8")
        builds = {
            int(key): value
            for key, value in json.loads(
                args.builds_json.read_text(encoding="utf-8")
            ).items()
        }
    else:
        if args.evaluation is None or args.evaluation < 0:
            parser.error("a nonnegative --evaluation is required for the live API")
        base = _loopback_url(args.base_url)
        jobs_json = _fetch(
            f"{base}/api/jobs?evaluation={args.evaluation}&system=x86_64-linux"
        )
        jobs = json.loads(jobs_json)
        if not isinstance(jobs, list):
            raise ValueError("invalid Cuirass jobs response")
        builds = {
            job["build"]: json.loads(_fetch(f"{base}/build/{quote(str(job['build']))}"))
            for job in jobs
        }
    report = reconcile(
        args.inventory.read_text(encoding="utf-8"), jobs_json, builds, "x86_64-linux"
    )
    json.dump(report, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, TypeError) as error:
        print(f"reconciliation error: {error}", file=sys.stderr)
        sys.exit(2)
