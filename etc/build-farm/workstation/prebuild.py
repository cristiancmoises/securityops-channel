#!/usr/bin/env python3
"""Pre-build System/Home with CT126 offload and mirror their runtime closures."""

import argparse
import importlib.util
import shlex
import subprocess
import sys
from pathlib import Path

SYNC_PATH = Path(__file__).with_name("sync-inventory.py")
spec = importlib.util.spec_from_file_location("farm_sync_prebuild", SYNC_PATH)
if spec is None or spec.loader is None:
    raise RuntimeError("farm inventory exporter is unavailable")
sync = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sync)


def build_command(source, root_drv):
    """Build the already-lowered exact root; never reevaluate changing config."""
    if (
        source not in ("system", "home")
        or not sync.catalog.STORE_PATH.fullmatch(root_drv)
        or not root_drv.endswith(".drv")
    ):
        raise ValueError("invalid exact root derivation")
    return [
        str(sync.GUIX),
        "build",
        "--max-jobs=0",
        f"--substitute-urls={sync.PRIVATE_SUBSTITUTES}",
        root_drv,
    ]


def copy_command(root):
    """Seed the farm's private publisher with the realized runtime closure."""
    return [str(sync.GUIX), "copy", "--max-jobs=0", "--to=farm-copy-ct126", root]


def pin_command(source, root):
    """Register the exact realized root in CT126's GC roots directory."""
    if source not in ("system", "home") or not sync.catalog.STORE_PATH.fullmatch(root):
        raise ValueError("invalid farm GC root target")
    remote = (
        "/var/guix/profiles/per-user/root/current-guix/bin/guix repl -q -- "
        "/usr/local/libexec/securityops-farm-pin-root "
        f"{shlex.quote(source)} {shlex.quote(root)}"
    )
    return ["ssh", "-T", "-o", "BatchMode=yes", "farm-copy-ct126", remote]


def run_source(source):
    """Offload missing builds, then mirror the realized runtime closure to CT126."""
    config = sync.SYSTEM_CONFIG if source == "system" else sync.HOME_CONFIG
    command = sync.command_for(
        source,
        str(config),
        guix=str(sync.GUIX),
        exporter=str(sync.EXPORTER),
        channels=str(sync.HOME_CHANNELS),
        channel=str(sync.LOCAL_CHANNEL),
        substitutes=sync.PRIVATE_SUBSTITUTES,
    )
    payload, manifest = sync.export_one(source, command)
    sync.upload(payload)
    root = manifest["root_output"]
    sync.upload(sync.activity_payload(source, [root]))
    try:
        process = subprocess.Popen(build_command(source, manifest["root_drv"]))
        while True:
            try:
                result = process.wait(timeout=300)
                break
            except subprocess.TimeoutExpired:
                sync.upload(sync.activity_payload(source, [root]))
    finally:
        sync.upload(sync.activity_payload(source, []))
    if result:
        return result
    copy_result = subprocess.run(copy_command(root), check=False)
    if copy_result.returncode:
        return copy_result.returncode
    return subprocess.run(pin_command(source, root), check=False).returncode


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", choices=("system", "home", "all"), default="all")
    args = parser.parse_args(argv)
    sources = ("system", "home") if args.source == "all" else (args.source,)
    for source in sources:
        print(
            f"{source}: exporting exact closure and building with zero local jobs",
            flush=True,
        )
        result = run_source(source)
        if result:
            return result
        print(f"{source}: build complete", flush=True)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
        print(f"farm prebuild failed: {error}", file=sys.stderr)
        sys.exit(1)
