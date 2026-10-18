#!/usr/bin/env python3
"""Export exact workstation targets and send only sanitized manifests to CT126."""

import argparse
import importlib.util
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
EXPORTER = ROOT / "etc/build-farm/workstation/export-closure"
CATALOG = ROOT / "etc/build-farm/site/catalog.py"
GUIX = Path.home() / ".config/guix/current/bin/guix"
SYSTEM_CONFIG = Path.home() / "guix-config/predator-helios-intel/config-river.scm"
HOME_CONFIG = Path.home() / ".config/guix/home.scm"
HOME_CHANNELS = Path.home() / ".config/guix/home-channels.scm"
LOCAL_CHANNEL = Path.home() / "securityops-channel"
PRIVATE_SUBSTITUTES = " ".join(
    url
    for url in (
        os.environ.get("SECURITYOPS_FARM_SUBSTITUTE_URL"),
        "https://substitutes.nonguix.org",
        "https://bordeaux.guix.gnu.org",
        "https://ci.guix.gnu.org",
    )
    if url
)
SSH_IDENTITY = Path.home() / ".ssh/securityops-farm-inventory-ct126"
SSH_KNOWN_HOSTS = Path.home() / ".ssh/securityops-farm-inventory-known-hosts"
SSH_TARGET = os.environ.get("SECURITYOPS_FARM_INVENTORY_TARGET", "")
EXPORT_TIMEOUT_SECONDS = 24 * 60 * 60

catalog_spec = importlib.util.spec_from_file_location("farm_catalog_sync", CATALOG)
if catalog_spec is None or catalog_spec.loader is None:
    raise RuntimeError("farm catalog validator is unavailable")
catalog = importlib.util.module_from_spec(catalog_spec)
catalog_spec.loader.exec_module(catalog)


def command_for(source, config, *, guix, exporter, channels, channel, substitutes):
    """Use exactly the System channel path or Home's pinned time-machine."""
    if source == "system":
        return [guix, "repl", "-q", "-L", channel, "--", exporter, source, config]
    if source == "home":
        return [
            guix,
            "time-machine",
            "-C",
            channels,
            "--max-jobs=0",
            f"--substitute-urls={substitutes}",
            "--",
            "repl",
            "-q",
            "--",
            exporter,
            source,
            config,
        ]
    raise ValueError("source must be system or home")


def export_one(source, command):
    """Fail closed if evaluation or the strict manifest contract fails."""
    result = subprocess.run(
        command, capture_output=True, timeout=EXPORT_TIMEOUT_SECONDS, check=False
    )
    if result.returncode:
        diagnostic = result.stderr.decode("utf-8", errors="replace")[-4000:]
        raise RuntimeError(f"{source} export failed: {diagnostic}")
    manifest = catalog.parse_manifest(result.stdout, datetime.now(timezone.utc))
    if manifest["source"] != source:
        raise ValueError("source mismatch in exported manifest")
    return result.stdout, manifest


def upload(payload):
    """The remote account is restricted to a fixed stdin-only receiver."""
    if not SSH_TARGET:
        raise RuntimeError("SECURITYOPS_FARM_INVENTORY_TARGET is required")
    result = subprocess.run(
        [
            "ssh",
            "-T",
            "-i",
            str(SSH_IDENTITY),
            "-o",
            "BatchMode=yes",
            "-o",
            "IdentitiesOnly=yes",
            "-o",
            "StrictHostKeyChecking=yes",
            "-o",
            f"UserKnownHostsFile={SSH_KNOWN_HOSTS}",
            "-o",
            "ConnectTimeout=10",
            SSH_TARGET,
        ],
        input=payload,
        capture_output=True,
        timeout=60,
        check=False,
    )
    if result.returncode:
        diagnostic = result.stderr.decode("utf-8", errors="replace")[-2000:]
        raise RuntimeError(f"farm inventory upload failed: {diagnostic}")


def activity_payload(source, paths):
    """Send only exact active outputs; the receiver checks inventory membership."""
    payload = json.dumps(
        {
            "schema": 1,
            "source": source,
            "updated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "active_outputs": paths,
        },
        separators=(",", ":"),
    ).encode("utf-8")
    catalog.parse_activity(payload, datetime.now(timezone.utc))
    return payload


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", choices=("all", "system", "home"), default="all")
    parser.add_argument(
        "--check-only", action="store_true", help="validate without upload"
    )
    parser.add_argument(
        "--activity",
        choices=("start", "stop"),
        help="mark one exact root build as active, or clear its signal",
    )
    args = parser.parse_args(argv)
    if args.activity and (args.source == "all" or args.check_only):
        parser.error("activity requires one source and an upload")
    if args.activity == "stop":
        upload(activity_payload(args.source, []))
        print(f"{args.source}: build activity cleared")
        return 0
    sources = ("system", "home") if args.source == "all" else (args.source,)
    for source in sources:
        config = SYSTEM_CONFIG if source == "system" else HOME_CONFIG
        command = command_for(
            source,
            str(config),
            guix=str(GUIX),
            exporter=str(EXPORTER),
            channels=str(HOME_CHANNELS),
            channel=str(LOCAL_CHANNEL),
            substitutes=PRIVATE_SUBSTITUTES,
        )
        payload, manifest = export_one(source, command)
        if not args.check_only:
            upload(payload)
            if args.activity == "start":
                upload(activity_payload(source, [manifest["root_output"]]))
        print(
            f"{source}: {len(manifest['entries'])} exact outputs, "
            f"root {manifest['root_drv']}, "
            f"{'validated locally' if args.check_only else 'uploaded'}"
        )
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
        print(f"inventory sync failed: {error}", file=sys.stderr)
        sys.exit(1)
