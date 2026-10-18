"""Versioned, sanitized inventory contract for the static farm catalog."""

import json
import re
from datetime import datetime, timedelta, timezone

MAX_MANIFEST_BYTES = 16 * 1024 * 1024
STORE_PATH = re.compile(r"^/gnu/store/[a-z0-9]{32}-[_A-Za-z0-9][_A-Za-z0-9+.?~-]*$")
TEXT = re.compile(r"^[_A-Za-z0-9][_A-Za-z0-9+.?~-]*$")
STAMP = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")
MANIFEST_KEYS = {
    "schema",
    "source",
    "system",
    "generated_at",
    "heartbeat_at",
    "root_drv",
    "root_output",
    "entries",
}
ENTRY_KEYS = {"path", "drv", "name", "version", "output", "kind", "direct"}
ACTIVITY_KEYS = {"schema", "source", "updated_at", "active_outputs"}


def _unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def _reject_constant(value):
    raise ValueError(f"invalid JSON constant: {value}")


def _document(payload):
    if not isinstance(payload, bytes) or len(payload) > MAX_MANIFEST_BYTES:
        raise ValueError("inventory must be bytes and at most 16 MiB")
    try:
        value = json.loads(
            payload.decode("utf-8"),
            object_pairs_hook=_unique_object,
            parse_constant=_reject_constant,
        )
    except (UnicodeDecodeError, json.JSONDecodeError, RecursionError) as error:
        raise ValueError("invalid UTF-8 JSON inventory") from error
    if not isinstance(value, dict):
        raise ValueError("inventory root must be an object")  # noqa: TRY004
    return value


def _keys(value, expected, label):
    if not isinstance(value, dict) or value.keys() != expected:
        raise ValueError(f"invalid {label} fields")


def _source(value):
    if value not in ("system", "home"):
        raise ValueError("unknown inventory source")


def _path(value, *, derivation=False):
    if not isinstance(value, str) or not STORE_PATH.fullmatch(value):
        raise ValueError("invalid exact store path")
    if derivation and not value.endswith(".drv"):
        raise ValueError("expected a derivation path")
    if not derivation and value.endswith(".drv"):
        raise ValueError("expected an output path")


def _text(value, label, *, empty=False):
    if not isinstance(value, str) or len(value) > 256:
        raise ValueError(f"invalid {label}")
    if not value and empty:
        return
    if not TEXT.fullmatch(value):
        raise ValueError(f"invalid {label}")


def _timestamp(value, now):
    if not isinstance(value, str) or not STAMP.fullmatch(value):
        raise ValueError("timestamp must be UTC RFC3339 to the second")
    try:
        stamp = datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ").replace(
            tzinfo=timezone.utc
        )
    except ValueError as error:
        raise ValueError("invalid timestamp") from error
    if now.tzinfo is None:
        raise ValueError("now must have a timezone")
    if stamp > now + timedelta(minutes=5):
        raise ValueError("future inventory timestamp")
    return stamp


def parse_manifest(payload, now, *, allow_stale=False):
    """Validate a target graph; only accepted snapshots may be read as stale."""
    value = _document(payload)
    _keys(value, MANIFEST_KEYS, "manifest")
    if type(value["schema"]) is not int or value["schema"] != 1:
        raise ValueError("unsupported manifest schema")
    _source(value["source"])
    if value["system"] != "x86_64-linux":
        raise ValueError("unexpected Guix system")
    generated = _timestamp(value["generated_at"], now)
    heartbeat = _timestamp(value["heartbeat_at"], now)
    if heartbeat < generated or (
        not allow_stale and now - heartbeat > timedelta(hours=24)
    ):
        raise ValueError("missing fresh laptop heartbeat")
    _path(value["root_drv"], derivation=True)
    _path(value["root_output"])
    entries = value["entries"]
    if not isinstance(entries, list) or not entries:
        raise ValueError("empty or invalid closure entries")
    seen = set()
    root_entry = None
    for entry in entries:
        _keys(entry, ENTRY_KEYS, "entry")
        _path(entry["path"])
        _path(entry["drv"], derivation=True)
        _text(entry["name"], "entry name")
        _text(entry["version"], "entry version", empty=True)
        _text(entry["output"], "output name")
        if (
            entry["kind"] not in ("package", "output")
            or type(entry["direct"]) is not bool
        ):
            raise ValueError("invalid entry kind or direct flag")
        if entry["path"] in seen:
            raise ValueError("duplicate exact output path")
        seen.add(entry["path"])
        if entry["path"] == value["root_output"]:
            root_entry = entry
    if root_entry is None:
        raise ValueError("root output missing from closure")
    if root_entry["drv"] != value["root_drv"] or root_entry["output"] != "out":
        raise ValueError("root output derivation mismatch")
    return value


def parse_activity(payload, now):
    """Validate a brief exact-output activity signal; consumers enforce expiry."""
    value = _document(payload)
    _keys(value, ACTIVITY_KEYS, "activity")
    if type(value["schema"]) is not int or value["schema"] != 1:
        raise ValueError("unsupported activity schema")
    _source(value["source"])
    value["updated_at"] = _timestamp(value["updated_at"], now)
    paths = value["active_outputs"]
    if not isinstance(paths, list):
        raise ValueError("invalid activity outputs")  # noqa: TRY004
    for path in paths:
        _path(path)
    if len(paths) != len(set(paths)):
        raise ValueError("duplicate activity outputs")
    return value


def merge_targets(manifests, channel_packages):
    """Join by output identity while retaining each source's direct/dependency badge."""
    targets = {}

    def include(path, source, *, direct, kind, name, version, output, drv, job=""):
        _path(path)
        target = targets.setdefault(path, {"path": path, "memberships": []})
        target["memberships"].append(
            {
                "source": source,
                "direct": direct,
                "kind": kind,
                "name": name,
                "version": version,
                "output": output,
                "drv": drv,
                "job": job,
            }
        )

    for manifest in manifests:
        source = manifest["source"]
        _source(source)
        for entry in manifest["entries"]:
            include(
                entry["path"],
                source,
                direct=entry["direct"],
                kind=entry["kind"],
                name=entry["name"],
                version=entry["version"],
                output=entry["output"],
                drv=entry["drv"],
            )
    for item in channel_packages:
        if not item.get("path"):
            continue
        include(
            item["path"],
            "channel",
            direct=True,
            kind="package",
            name=item["name"],
            version="",
            output="out",
            drv="",
            job=item["job"],
        )
    for target in targets.values():
        memberships = target["memberships"]
        memberships.sort(key=lambda item: item["source"])
        target["sources"] = [item["source"] for item in memberships]
        target["direct_sources"] = [
            item["source"] for item in memberships if item["direct"]
        ]
    return [targets[path] for path in sorted(targets)]


def target_state(target, public_paths, local_paths, active_paths, now):
    """Public > CT-valid > fresh exact-output activity > unavailable."""
    path = target["path"]
    if path in public_paths:
        return "available"
    if path in local_paths:
        return "stored"
    updated = active_paths.get(path)
    if updated is not None and timedelta(minutes=-5) <= now - updated <= timedelta(
        minutes=15
    ):
        return "building"
    return "unavailable"
