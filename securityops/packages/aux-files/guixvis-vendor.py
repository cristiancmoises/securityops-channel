# SPDX-License-Identifier: GPL-3.0-or-later
"""Prepare Cargo's directory source from the Guix inputs and upstream lockfile."""

import hashlib
import json
import sys
import tarfile
from pathlib import Path

import tomllib


def sha256(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def main(archives):
    with Path("Cargo.lock").open("rb") as stream:
        packages = tomllib.load(stream)["package"]
    locked = {
        package["checksum"]: f"{package['name']}-{package['version']}"
        for package in packages
        if package.get("source")
        == "registry+https://github.com/rust-lang/crates.io-index"
    }
    vendor = Path("vendor")
    vendor.mkdir()
    for archive in archives:
        checksum = sha256(archive)
        crate = locked.pop(checksum)
        with tarfile.open(archive, "r:gz") as tar:
            for member in tar:
                parts = Path(member.name).parts
                if not parts or parts[0] != crate or ".." in parts:
                    raise ValueError(f"Unexpected path in {crate}")
                if not (member.isfile() or member.isdir()):
                    raise ValueError(f"Unexpected member type in {crate}")
                tar.extract(member, vendor, filter="data")
        root = vendor / crate
        files = {
            path.relative_to(root).as_posix(): sha256(path)
            for path in sorted(root.rglob("*"))
            if path.is_file()
        }
        with (root / ".cargo-checksum.json").open("x", encoding="utf-8") as stream:
            json.dump(
                {"files": files, "package": checksum}, stream, separators=(",", ":")
            )
    if locked:
        raise ValueError(
            f"Missing crates from Cargo.lock: {', '.join(sorted(locked.values()))}"
        )


if __name__ == "__main__":
    main(map(Path, sys.argv[1:]))
