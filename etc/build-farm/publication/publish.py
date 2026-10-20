"""Plan or publish reviewed CT126 package closures through CT116.

Dry-run is the default.  Each approval binds an exact output to SHA-256 of its
sorted `guix gc --requisites` paths, joined with a final newline.  The human
reviewer records redistribution and notice obligations in license_basis.
The committed empty policy deliberately holds every unknown output.
"""

import argparse
import csv
import hashlib
import importlib.util
import io
import json
import os
import re
import stat
import subprocess
import sys
import tempfile
from datetime import datetime, timedelta, timezone
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import HTTPRedirectHandler, Request, build_opener

CATALOG = Path(__file__).resolve().parents[1] / "site/catalog.py"
_catalog_spec = importlib.util.spec_from_file_location(
    "farm_publication_catalog", CATALOG
)
if _catalog_spec is None or _catalog_spec.loader is None:
    raise RuntimeError("farm catalog validator is unavailable")
catalog = importlib.util.module_from_spec(_catalog_spec)
_catalog_spec.loader.exec_module(catalog)

STORE_PATH = re.compile(r"^/gnu/store/[a-z0-9]{32}-[_A-Za-z0-9][_A-Za-z0-9+.?~-]*$")
REVIEW_TRIGGER = re.compile(
    r"(?:^|[-_.])(?:nvidia|cuda|linux-firmware|nonfree|unfree|proprietary|steam|google-chrome)(?:[-_.]|$)",
    re.IGNORECASE,
)
GUIX = "/var/guix/profiles/per-user/root/current-guix/bin/guix"
MAX_CLOSURE_PATHS = 4096
MAX_ARCHIVE_BYTES = 16 * 1024**3
MAX_CLOSURE_ENTRIES = 1_000_000
DESTINATION_OVERHEAD_PER_ENTRY = 8192
POLICY_PATH = Path(__file__).with_name("reviewed-closures.json")
PUBLIC_URL = "https://substitutes.securityops.co"
CT116_PUBLIC_URL = os.environ.get("SECURITYOPS_CT116_PUBLIC_URL")
NAR_HASH = re.compile(r"^sha256:[a-z0-9]{52}$")
NAR_URL = re.compile(r"^nar/[A-Za-z0-9._+/-]+$")
SQL = """
SELECT e.id, e.timestamp, j.name, j.status,
       b.id, b.nix_name, b.status, COALESCE(b.starttime, 0),
       COALESCE(b.stoptime, 0), o.name, o.path
FROM (SELECT id, timestamp FROM evaluations
      WHERE specification = 'securityops' AND status = 0
      ORDER BY id DESC LIMIT 1) AS e
JOIN jobs j ON j.evaluation = e.id AND j.system = 'x86_64-linux'
JOIN builds b ON b.id = j.build
LEFT JOIN outputs o ON o.derivation = b.derivation AND o.name = 'out'
ORDER BY j.name
"""
READ_INVENTORY = """import os, stat, sys
try:
    fd = os.open(sys.argv[1], os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW)
except FileNotFoundError:
    sys.stdout.buffer.write(b'M')
    sys.exit(0)
try:
    if not stat.S_ISREG(os.fstat(fd).st_mode):
        raise ValueError("inventory is not a regular file")
    data = os.read(fd, 16 * 1024 * 1024 + 1)
    if len(data) > 16 * 1024 * 1024:
        raise ValueError("inventory exceeds 16 MiB")
    sys.stdout.buffer.write(b'P' + data)
finally:
    os.close(fd)
"""


def exact_output(path):
    if (
        not isinstance(path, str)
        or not STORE_PATH.fullmatch(path)
        or path.endswith(".drv")
    ):
        raise ValueError("invalid exact store path")
    return path


def parse_cuirass_csv(value):
    """Read one completed SecurityOps evaluation returned by the fixed SQL query."""
    rows = []
    seen = set()
    identity = None
    for row in csv.reader(io.StringIO(value)):
        if len(row) != 11:
            raise ValueError("invalid Cuirass snapshot columns")
        (
            evaluation,
            timestamp,
            job,
            job_status,
            build_id,
            name,
            build_status,
            started,
            stopped,
            output,
            path,
        ) = row
        if not job or not name or not build_id or job in seen:
            raise ValueError("incomplete or duplicate Cuirass job")
        seen.add(job)
        int(build_id)
        int(started)
        current = (int(evaluation), int(timestamp))
        if identity is None:
            identity = current
        elif current != identity:
            raise ValueError("mixed Cuirass evaluations")
        if path:
            exact_output(path)
        if output not in ("", "out"):
            raise ValueError("unexpected Cuirass output")
        rows.append(
            {
                "job": job,
                "job_status": int(job_status),
                "build_status": int(build_status),
                "stopped": int(stopped),
                "path": path,
                "output": output,
            }
        )
    if identity is None:
        raise ValueError("completed evaluation has no jobs")
    return {"evaluation": identity[0], "timestamp": identity[1], "packages": rows}


def validate_manifest(payload, source, now, *, allow_stale=False):
    """Use the accepted inventory contract, including its 24-hour heartbeat."""
    if source not in ("system", "home"):
        raise ValueError("unknown inventory source")
    manifest = catalog.parse_manifest(payload, now, allow_stale=allow_stale)
    if manifest["source"] != source:
        raise ValueError("inventory source mismatch")
    return manifest


def select_targets(snapshot, manifests):
    """Channel jobs need success; System/Home entries need a fresh manifest."""
    roots = {manifest["root_output"] for manifest in manifests}
    selected = set()
    failed = set()
    held = []
    for item in snapshot["packages"]:
        path = item["path"]
        if not path:
            held.append({"job": item["job"], "reason": "missing_output"})
            continue
        if path in roots:
            continue
        if (
            item["job_status"] != 0
            or item["build_status"] != 0
            or item["stopped"] <= 0
            or item["output"] != "out"
        ):
            held.append({"path": path, "reason": "unsuccessful_job"})
            failed.add(path)
            continue
        selected.add(exact_output(path))
    for manifest in manifests:
        for item in manifest["entries"]:
            if item["kind"] == "package" and item["path"] not in roots:
                selected.add(exact_output(item["path"]))
    return sorted(selected - failed), held


def collect_targets(transport, now, *, include_workstation=False):
    """Select channel outputs; private workstation inventories require opt-in."""
    snapshot = parse_cuirass_csv(
        transport.run(
            126,
            [
                "runuser",
                "-u",
                "farm_site",
                "--",
                "psql",
                "-X",
                "--csv",
                "--tuples-only",
                "-d",
                "cuirass",
                "-c",
                SQL,
            ],
        ).decode("utf-8")
    )
    manifests = []
    inventory_holds = []
    for source in ("system", "home") if include_workstation else ():
        path = f"/var/lib/farm-site/inventory/{source}.json"
        response = transport.run(126, ["/usr/bin/python3", "-c", READ_INVENTORY, path])
        if response == b"M":
            inventory_holds.append({"source": source, "reason": "missing_inventory"})
            continue
        if not response.startswith(b"P"):
            raise ValueError("invalid inventory reader response")
        manifest = validate_manifest(response[1:], source, now, allow_stale=True)
        heartbeat = datetime.fromisoformat(
            manifest["heartbeat_at"].replace("Z", "+00:00")
        )
        if now - heartbeat > timedelta(hours=24):
            inventory_holds.append({"source": source, "reason": "stale_inventory"})
            continue
        manifests.append(manifest)
    selected, held = select_targets(snapshot, manifests)
    return selected, inventory_holds + held, snapshot["evaluation"]


def _unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate review policy field")
        result[key] = value
    return result


def parse_policy(payload):
    """Require a human record for an exact path and its complete requisites."""
    if not isinstance(payload, bytes) or len(payload) > 1024 * 1024:
        raise ValueError("invalid review policy size")
    try:
        value = json.loads(payload.decode("utf-8"), object_pairs_hook=_unique_object)
    except (UnicodeDecodeError, json.JSONDecodeError, RecursionError) as error:
        raise ValueError("invalid review policy JSON") from error
    if not isinstance(value, dict) or value.keys() != {"schema", "approved", "denied"}:
        raise ValueError("invalid review policy fields")
    if type(value["schema"]) is not int or value["schema"] != 1:
        raise ValueError("unsupported review policy schema")
    if not isinstance(value["approved"], list) or not isinstance(value["denied"], list):
        raise ValueError("invalid review policy lists")  # noqa: TRY004
    approved = {}
    for record in value["approved"]:
        expected = {
            "path",
            "requisites_sha256",
            "reviewed_by",
            "reviewed_at",
            "license_basis",
        }
        if not isinstance(record, dict) or record.keys() != expected:
            raise ValueError("invalid review record")
        path = exact_output(record["path"])
        if path in approved:
            raise ValueError("duplicate review record")
        digest = record["requisites_sha256"]
        if not isinstance(digest, str) or not re.fullmatch(r"[0-9a-f]{64}", digest):
            raise ValueError("invalid requisite digest")
        for field in ("reviewed_by", "reviewed_at", "license_basis"):
            text = record[field]
            if not isinstance(text, str) or not text.strip() or len(text) > 1024:
                raise ValueError(f"invalid {field}")
        if not catalog.STAMP.fullmatch(record["reviewed_at"]):
            raise ValueError("invalid reviewed_at")
        try:
            datetime.strptime(record["reviewed_at"], "%Y-%m-%dT%H:%M:%SZ").replace(
                tzinfo=timezone.utc
            )
        except ValueError as error:
            raise ValueError("invalid reviewed_at") from error
        approved[path] = record
    denied = {exact_output(path) for path in value["denied"]}
    if len(denied) != len(value["denied"]) or denied.intersection(approved):
        raise ValueError("duplicate or conflicting review decision")
    return {"approved": approved, "denied": denied}


def _guix_paths(payload, *, root=None, allowed=None):
    try:
        paths = payload.decode("utf-8").splitlines()
    except UnicodeDecodeError as error:
        raise ValueError("invalid Guix path output") from error
    if len(paths) > MAX_CLOSURE_PATHS or len(paths) != len(set(paths)):
        raise ValueError("invalid or excessive Guix path output")
    for path in paths:
        exact_output(path)
    if root is not None and root not in paths:
        raise ValueError("Guix requisites omitted requested output")
    if allowed is not None and not set(paths) <= set(allowed):
        raise ValueError("Guix reported an unrequested path")
    return paths


def _missing(transport, ct, paths):
    payload = ("\n".join(sorted(paths)) + "\n").encode()
    return set(
        _guix_paths(
            transport.run(ct, [GUIX, "archive", "--missing"], input=payload),
            allowed=paths,
        )
    )


def _closure_footprint(transport, paths):
    """Measure logical bytes and entries; bound destination block overhead."""
    totals = []
    for options in (
        ["--apparent-size", "-B1"],
        ["--inodes"],
    ):
        output = transport.run(
            126, ["du", "-s", *options, "--count-links", "--", *sorted(paths)]
        )
        seen = set()
        total = 0
        for line in output.decode("utf-8").splitlines():
            value, separator, path = line.partition("\t")
            if (
                not separator
                or not value.isdecimal()
                or path not in paths
                or path in seen
            ):
                raise ValueError("invalid closure footprint output")
            total += int(value)
            seen.add(path)
        if seen != set(paths):
            raise ValueError("incomplete closure footprint output")
        totals.append(total)
    if totals[1] < len(paths):
        raise ValueError("invalid closure entry count")
    return tuple(totals)


def _pin_source(path):
    exact_output(path)
    return f'''(use-modules (guix store))
(define path "{path}")
(define root-directory "/var/guix/gcroots/securityops-publication")
(unless (valid-path-syntax? path) (error "invalid publication path"))
(unless (file-exists? root-directory) (mkdir root-directory #o755))
(unless (file-is-directory? root-directory) (error "publication root directory unavailable"))
(with-store store
  (unless (valid-path? store path) (error "publication output not valid"))
  (let* ((root (string-append root-directory "/" (store-path-hash-part path)))
         (existing (false-if-exception (readlink root))))
    (cond ((not existing) (symlink path root))
          ((not (string=? existing path)) (error "publication GC root conflict")))
    (add-indirect-root store root)))
'''.encode()


class NoRedirects(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ValueError(f"unexpected substitute redirect: HTTP {code}")


def validate_narinfo(path, document):
    """A public 200 must describe this exact output with a signed NAR."""
    exact_output(path)
    fields = {}
    for line in document.splitlines():
        if not line.strip():
            continue
        key, separator, value = line.partition(": ")
        if not separator:
            raise ValueError("malformed public narinfo")
        fields.setdefault(key, []).append(value)
    if fields.get("StorePath") != [path]:
        raise ValueError("public narinfo path mismatch")
    if len(fields.get("NarHash", [])) != 1 or not NAR_HASH.fullmatch(
        fields["NarHash"][0]
    ):
        raise ValueError("public narinfo lacks NAR hash")
    urls = fields.get("URL", [])
    if not urls or any(
        not NAR_URL.fullmatch(url)
        or any(segment in ("", ".", "..") for segment in url.split("/"))
        for url in urls
    ):
        raise ValueError("public narinfo has invalid NAR URL")
    if not any(signature.strip() for signature in fields.get("Signature", [])):
        raise ValueError("public narinfo is unsigned")
    return True


def check_public_output(path, base_url=PUBLIC_URL):
    exact_output(path)
    store_hash = path.removeprefix("/gnu/store/").split("-", 1)[0]
    request = Request(
        f"{base_url}/{store_hash}.narinfo",
        headers={"Accept": "text/plain", "User-Agent": "securityops-publication/1"},
    )
    try:
        with build_opener(NoRedirects()).open(request, timeout=8) as response:
            if response.status != 200:
                raise ValueError(f"unexpected narinfo status: {response.status}")
            payload = response.read(65537)
            if len(payload) > 65536:
                raise ValueError("public narinfo exceeds 64 KiB")
    except HTTPError as error:
        if error.code == 404:
            return False
        raise
    document = payload.decode("utf-8")
    validate_narinfo(path, document)
    nar_url = next(
        line.partition(": ")[2]
        for line in document.splitlines()
        if line.startswith("URL: ")
    )
    request = Request(
        f"{base_url}/{nar_url}",
        headers={"Range": "bytes=0-0", "User-Agent": "securityops-publication/1"},
    )
    try:
        with build_opener(NoRedirects()).open(request, timeout=30) as response:
            if response.status not in (200, 206) or not response.read(1):
                raise ValueError("advertised public NAR is unavailable")
    except HTTPError as error:
        if error.code == 404:
            raise ValueError("advertised public NAR is unavailable") from error
        raise
    return True


def check_both_publishers(path):
    if not CT116_PUBLIC_URL:
        raise RuntimeError("SECURITYOPS_CT116_PUBLIC_URL is required")
    return check_public_output(path, CT116_PUBLIC_URL) and check_public_output(path)


def check_capacity(thin_pool, free_bytes, archive_bytes, free_inodes, entries):
    """Reserve CT116 data and inodes, and respect the host thin-pool guard."""
    parts = thin_pool.split()
    if len(parts) != 3 or any(
        not re.fullmatch(r"[0-9]+(?:\.[0-9]+)?", part) for part in parts
    ):
        raise RuntimeError("invalid thin pool metrics")
    pool_bytes, data_percent, metadata_percent = map(float, parts)
    if (
        pool_bytes <= 0
        or archive_bytes < 0
        or type(free_inodes) is not int
        or type(entries) is not int
        or entries < 0
    ):
        raise RuntimeError("invalid thin pool metrics")
    guarded_bytes = archive_bytes * 1.25 + 1024**3
    if data_percent + guarded_bytes / pool_bytes * 100 >= 80 or metadata_percent >= 85:
        raise RuntimeError("thin pool guard stopped publication")
    if free_bytes < guarded_bytes + 10 * 1024**3:
        raise RuntimeError("CT116 space guard stopped publication")
    if free_inodes < entries + 100_000:
        raise RuntimeError("CT116 inode guard stopped publication")


class HostTransport:
    """Only fixed CT126/CT116 commands; never invoke a shell or build."""

    def __init__(self, pct="pct"):
        self.pct = pct

    def _pct(self, ct, argv):
        if ct not in (126, 116):
            raise ValueError("unexpected container ID")
        return [self.pct, "exec", str(ct), "--", *argv]

    def run(self, ct, argv, input=None):
        result = subprocess.run(
            self._pct(ct, argv),
            input=input,
            capture_output=True,
            check=False,
            timeout=180,
        )
        if result.returncode:
            detail = result.stderr.decode("utf-8", errors="replace")[-2000:]
            raise RuntimeError(f"CT{ct} command failed ({result.returncode}): {detail}")
        return result.stdout

    def ensure_capacity(self, archive_bytes, entries):
        if Path("/var/lib/securityops-build-farm/PAUSED").exists():
            raise RuntimeError("build farm pause marker blocks publication")
        result = subprocess.run(
            [
                "lvs",
                "--noheadings",
                "--units",
                "b",
                "--nosuffix",
                "-o",
                "lv_size,data_percent,metadata_percent",
                "pve/data",
            ],
            capture_output=True,
            check=False,
            timeout=30,
        )
        if result.returncode:
            raise RuntimeError("thin pool metrics unavailable")
        lines = result.stdout.decode("utf-8").splitlines()
        if len(lines) != 1:
            raise RuntimeError("invalid thin pool metrics")
        df = self.run(116, ["df", "-B1", "--output=avail,iavail", "/gnu/store"])
        fields = df.decode("utf-8").split()
        if (
            len(fields) != 4
            or fields[:2] != ["Avail", "IFree"]
            or not all(item.isdecimal() for item in fields[2:])
        ):
            raise RuntimeError("CT116 space metrics unavailable")
        check_capacity(lines[0], int(fields[2]), archive_bytes, int(fields[3]), entries)

    def stream_archive(self, path, *, max_bytes=MAX_ARCHIVE_BYTES):
        exact_output(path)
        if type(max_bytes) is not int or max_bytes < 1 or max_bytes > MAX_ARCHIVE_BYTES:
            raise ValueError("invalid archive byte limit")
        export = self._pct(
            126,
            [
                GUIX,
                "archive",
                "--export",
                "--recursive",
                "--max-jobs=0",
                "--no-substitutes",
                path,
            ],
        )
        archive_import = self._pct(116, [GUIX, "archive", "--import"])
        with (
            tempfile.TemporaryFile() as export_errors,
            tempfile.TemporaryFile() as import_errors,
        ):
            producer = subprocess.Popen(
                export, stdout=subprocess.PIPE, stderr=export_errors
            )
            consumer = None
            try:
                if producer.stdout is None:
                    raise RuntimeError("archive exporter has no stream")
                consumer = subprocess.Popen(
                    archive_import,
                    stdin=subprocess.PIPE,
                    stdout=subprocess.DEVNULL,
                    stderr=import_errors,
                )
                if consumer.stdin is None:
                    raise RuntimeError("archive importer has no input stream")
                transferred = 0
                import_broken_pipe = False
                while chunk := producer.stdout.read(1024 * 1024):
                    transferred += len(chunk)
                    if transferred > max_bytes:
                        raise RuntimeError("archive byte guard stopped transfer")
                    try:
                        consumer.stdin.write(chunk)
                    except BrokenPipeError:
                        import_broken_pipe = True
                        producer.stdout.close()
                        break
                try:
                    consumer.stdin.close()
                except BrokenPipeError:
                    import_broken_pipe = True
                export_status = producer.wait(timeout=60)
                import_status = consumer.wait(timeout=3600)
            finally:
                if producer.stdout is not None:
                    producer.stdout.close()
                if consumer is not None and consumer.stdin is not None:
                    try:
                        consumer.stdin.close()
                    except BrokenPipeError:
                        pass
                for process in (consumer, producer):
                    if process is not None and process.poll() is None:
                        process.kill()
                        process.wait()
            if import_broken_pipe or export_status or import_status:
                import_errors.seek(0, os.SEEK_END)
                import_errors.seek(max(0, import_errors.tell() - 1000))
                export_errors.seek(0, os.SEEK_END)
                export_errors.seek(max(0, export_errors.tell() - 1000))
                detail = (import_errors.read() + export_errors.read())[-2000:]
                raise RuntimeError(
                    f"signed archive transfer failed (export={export_status}, import={import_status}): "
                    + detail.decode("utf-8", errors="replace")
                )


def publish_paths(paths, policy, transport, public_check, *, apply=False, limit=3):
    """Bounded, fail-closed transfer. The transport performs no builds."""
    if type(limit) is not int or not 0 <= limit <= 20:
        raise ValueError("invalid per-run limit")
    result = {
        "planned": [],
        "public_routes_reachable": [],
        "already_routes_reachable": [],
        "held": [],
    }
    attempted = 0
    for path in paths:
        exact_output(path)
        if path in policy["denied"] or REVIEW_TRIGGER.search(path):
            result["held"].append({"path": path, "reason": "known_review_trigger"})
            continue
        review = policy["approved"].get(path)
        if review is None:
            result["held"].append({"path": path, "reason": "unreviewed_redistribution"})
            continue
        if attempted >= limit:
            result["held"].append({"path": path, "reason": "run_limit"})
            continue
        attempted += 1
        requisites = _guix_paths(
            transport.run(126, [GUIX, "gc", "--requisites", path]), root=path
        )
        if any(
            item in policy["denied"] or REVIEW_TRIGGER.search(item)
            for item in requisites
        ):
            result["held"].append({"path": path, "reason": "known_review_trigger"})
            continue
        digest = hashlib.sha256(
            ("\n".join(sorted(requisites)) + "\n").encode()
        ).hexdigest()
        if digest != review["requisites_sha256"]:
            result["held"].append({"path": path, "reason": "closure_changed"})
            continue
        if _missing(transport, 126, requisites):
            result["held"].append({"path": path, "reason": "missing_on_builder"})
            continue
        missing_public = _missing(transport, 116, requisites)
        if not missing_public:
            if not all(public_check(item) for item in requisites):
                result["held"].append(
                    {"path": path, "reason": "ct116_present_not_public"}
                )
                continue
            if apply:
                for ct in (126, 116):
                    transport.run(
                        ct,
                        [GUIX, "repl", "-q", "--", "/dev/stdin"],
                        input=_pin_source(path),
                    )
            result["already_routes_reachable"].append(path)
            continue
        size, entries = _closure_footprint(transport, requisites)
        if size > MAX_ARCHIVE_BYTES or entries > MAX_CLOSURE_ENTRIES:
            result["held"].append({"path": path, "reason": "oversized_closure"})
            continue
        estimated_destination_bytes = size + entries * DESTINATION_OVERHEAD_PER_ENTRY
        transport.ensure_capacity(estimated_destination_bytes, entries)
        if not apply:
            result["planned"].append(path)
            continue
        transport.run(
            126, [GUIX, "repl", "-q", "--", "/dev/stdin"], input=_pin_source(path)
        )
        transport.stream_archive(
            path, max_bytes=min(MAX_ARCHIVE_BYTES, int(size * 1.25 + 1024**3))
        )
        if _missing(transport, 116, requisites):
            raise RuntimeError(f"archive import left missing CT116 requisites: {path}")
        transport.run(
            116, [GUIX, "repl", "-q", "--", "/dev/stdin"], input=_pin_source(path)
        )
        if not all(public_check(item) for item in requisites):
            raise RuntimeError(
                f"public narinfo unavailable for closure after import: {path}"
            )
        result["public_routes_reachable"].append(path)
    return result


def _read_policy():
    descriptor = os.open(POLICY_PATH, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW)
    with os.fdopen(descriptor, "rb") as stream:
        if not stat.S_ISREG(os.fstat(stream.fileno()).st_mode):
            raise ValueError("review policy is not a regular file")
        return parse_policy(stream.read(1024 * 1024 + 1))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--apply", action="store_true", help="perform reviewed imports and GC pinning"
    )
    parser.add_argument(
        "--limit", type=int, default=3, help="maximum reviewed targets this run (0-20)"
    )
    parser.add_argument(
        "--include-workstation",
        action="store_true",
        help="also consider reviewed packages from private System/Home inventories",
    )
    args = parser.parse_args(argv)
    transport = HostTransport()
    policy = _read_policy()
    selected, held, evaluation = collect_targets(
        transport,
        datetime.now(timezone.utc),
        include_workstation=args.include_workstation,
    )
    outcome = publish_paths(
        selected,
        policy,
        transport,
        check_both_publishers,
        apply=args.apply,
        limit=args.limit,
    )
    outcome["held"] = held + outcome["held"]
    print(
        json.dumps(
            {
                "evaluation": evaluation,
                "dry_run": not args.apply,
                "include_workstation": args.include_workstation,
                **outcome,
            },
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (
        OSError,
        ValueError,
        RuntimeError,
        UnicodeError,
        subprocess.TimeoutExpired,
        URLError,
    ) as error:
        print(f"publication failed: {error}", file=sys.stderr)
        sys.exit(1)
