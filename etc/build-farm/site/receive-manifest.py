#!/usr/bin/env python3
"""Forced SSH command for the private System/Home inventory inbox."""

import errno
import fcntl
import importlib.util
import os
import stat
import sys
import tempfile
from datetime import datetime, timedelta, timezone
from pathlib import Path

INBOX = Path("/var/lib/farm-site/inventory")
CATALOG = Path(__file__).with_name("catalog.py")

catalog_spec = importlib.util.spec_from_file_location("farm_catalog_receiver", CATALOG)
if catalog_spec is None or catalog_spec.loader is None:
    raise RuntimeError("farm catalog validator is unavailable")
catalog = importlib.util.module_from_spec(catalog_spec)
catalog_spec.loader.exec_module(catalog)


def receive_payload(payload, inbox, *, now=None):
    """Validate before replacing one fixed manifest or short-lived activity file."""
    if now is None:
        now = datetime.now(timezone.utc)
    try:
        document = catalog.parse_manifest(payload, now)
        is_activity = False
    except ValueError:
        document = catalog.parse_activity(payload, now)
        is_activity = True
    inbox = Path(inbox)
    if inbox.is_symlink() or not inbox.is_dir():
        raise ValueError("inventory inbox must be a real directory")
    directory_descriptor = os.open(inbox, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        if stat.S_IMODE(os.fstat(directory_descriptor).st_mode) & 0o002:
            raise ValueError("inventory inbox must not be world-writable")
        fcntl.flock(directory_descriptor, fcntl.LOCK_EX)
        if is_activity:
            if now - document["updated_at"] > timedelta(minutes=15):
                raise ValueError("expired activity cannot be accepted")
            manifest_path = inbox / f"{document['source']}.json"
            try:
                manifest_descriptor = os.open(
                    manifest_path, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW
                )
            except FileNotFoundError as error:
                raise ValueError("activity requires an accepted inventory") from error
            with os.fdopen(manifest_descriptor, "rb") as manifest_stream:
                if not stat.S_ISREG(os.fstat(manifest_stream.fileno()).st_mode):
                    raise ValueError("accepted inventory is not a regular file")
                accepted = catalog.parse_manifest(
                    manifest_stream.read(catalog.MAX_MANIFEST_BYTES + 1),
                    now,
                    allow_stale=True,
                )
            if accepted["source"] != document["source"]:
                raise ValueError("accepted inventory source mismatch")
            known_paths = {entry["path"] for entry in accepted["entries"]}
            if not set(document["active_outputs"]) <= known_paths:
                raise ValueError("activity is not in the accepted inventory")
            generated_at = datetime.fromisoformat(
                accepted["generated_at"].replace("Z", "+00:00")
            )
            if document["updated_at"] < generated_at:
                raise ValueError("activity predates accepted inventory")
        suffix = "-activity" if is_activity else ""
        destination = inbox / f"{document['source']}{suffix}.json"
        try:
            existing_descriptor = os.open(
                destination, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW
            )
        except FileNotFoundError:
            pass
        except OSError as error:
            if error.errno != errno.ELOOP:
                raise
            # A symlink is never followed; atomic replace will unlink it.
        else:
            with os.fdopen(existing_descriptor, "rb") as existing_stream:
                if not stat.S_ISREG(os.fstat(existing_stream.fileno()).st_mode):
                    raise ValueError("existing inventory is not a regular file")
                existing_payload = existing_stream.read(catalog.MAX_MANIFEST_BYTES + 1)
            if is_activity:
                existing = catalog.parse_activity(existing_payload, now)
                older = existing["updated_at"] > document["updated_at"]
            else:
                existing = catalog.parse_manifest(
                    existing_payload, now, allow_stale=True
                )
                older = (
                    existing["generated_at"] > document["generated_at"]
                    or existing["generated_at"] == document["generated_at"]
                    and existing["heartbeat_at"] > document["heartbeat_at"]
                )
            if existing["source"] != document["source"]:
                raise ValueError("existing inventory source mismatch")
            if older:
                raise ValueError("older inventory cannot replace a newer one")
        descriptor, temporary = tempfile.mkstemp(prefix=".incoming-", dir=inbox)
        try:
            with os.fdopen(descriptor, "wb") as stream:
                os.fchmod(stream.fileno(), 0o640)
                stream.write(payload)
                stream.flush()
                os.fsync(stream.fileno())
            os.replace(temporary, destination)
            os.fsync(directory_descriptor)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)
    finally:
        os.close(directory_descriptor)
    return destination


def main():
    if os.environ.get("SSH_ORIGINAL_COMMAND"):
        raise ValueError("remote commands are not accepted")
    payload = sys.stdin.buffer.read(catalog.MAX_MANIFEST_BYTES + 1)
    destination = receive_payload(payload, INBOX)
    print(f"accepted {destination.name}")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError):
        print("manifest rejected", file=sys.stderr)
        sys.exit(1)
