# SPDX-License-Identifier: GPL-3.0-or-later
"""Run the immutable activation, never Wazuh, in private namespaces and a chroot.

Usage: python3 tests/wazuh-activation-bundle.py BUNDLE
The synthetic root/wazuh accounts both use namespace UID/GID 0; the test checks
activation and store isolation, not production account privilege separation.
"""

import os
import stat
import subprocess
import sys
import tempfile
from pathlib import Path

SYSTEM_BIN = Path("/run/current-system/profile/bin")
CLEAN_ENV = {"LC_ALL": "C", "PATH": "/nonexistent", "GUILE_AUTO_COMPILE": "0"}
STATE_DIRECTORIES = (
    ".",
    "etc",
    "etc/shared",
    "logs",
    "queue",
    "gnu",
    "active-response",
)


def run(*arguments):
    return subprocess.run(
        list(map(str, arguments)),
        env=CLEAN_ENV,
        check=True,
        capture_output=True,
        text=True,
        timeout=60,
    )


def inside(bundle, root, parent_mount):
    if (
        os.geteuid() != 0
        or Path("/proc/self/ns/mnt").readlink() == Path(parent_mount)
        or Path("/gnu/store").stat().st_uid == 0
    ):
        raise RuntimeError("A private user and mount namespace is required")
    mount = SYSTEM_BIN / "mount"
    run(mount, "--make-rprivate", "/")
    for relative in ("etc", "gnu/store", "proc", "var/lib"):
        (root / relative).mkdir(parents=True, exist_ok=True)
    (root / "etc/passwd").write_text(
        "root:x:0:0:root:/:/no-shell\nwazuh:x:0:0:test:/:/no-shell\n"
    )
    (root / "etc/group").write_text("root:x:0:\nwazuh:x:0:\n")
    (root / "etc/nsswitch.conf").write_text("passwd: files\ngroup: files\n")
    run(mount, "--bind", "/gnu/store", root / "gnu/store")
    run(mount, "-o", "remount,bind,ro", root / "gnu/store")
    run(mount, "-t", "proc", "-o", "nosuid,nodev,noexec", "proc", root / "proc")

    # This runs the generated store executable with no ambient Guile paths.
    # Missing imported modules must fail here, before the state exists.
    os.umask(0o077)  # Match the privileged installer's restrictive environment.
    run(SYSTEM_BIN / "chroot", root, bundle / "activate")
    state = root / "var/lib/wazuh-agent"
    created_modes = {
        relative: stat.S_IMODE((state / relative).stat().st_mode)
        for relative in (*STATE_DIRECTORIES, "gnu/store")
    }
    assert (state / "bin").is_symlink()
    assert str((state / "bin").readlink()).startswith("/gnu/store/")
    assert stat.S_IMODE((state / "etc/client.keys").stat().st_mode) == 0o640
    assert (state / "queue/syscollector/norm_config.json").is_file()
    assert (state / "etc/local_internal_options.conf").read_text() == (
        "agent.remote_conf=0\nlogcollector.remote_commands=0\n"
        "wazuh_command.remote_commands=0\nsca.remote_commands=0\n"
    )
    keys = state / "etc/client.keys"
    keys.write_text("synthetic-existing-key\n")
    # Model a previously activated state made inaccessible by umask 077.
    # Repairs must preserve enrollment and the read-only mounted store.
    for relative in STATE_DIRECTORIES:
        (state / relative).chmod(0o700)
    run(mount, "--bind", "/gnu/store", state / "gnu/store")
    run(mount, "-o", "remount,bind,ro", state / "gnu/store")
    run(SYSTEM_BIN / "chroot", root, bundle / "activate")
    assert keys.read_text() == "synthetic-existing-key\n"
    assert (state / "gnu/store").stat().st_ino == Path("/gnu/store").stat().st_ino
    repaired_modes = {
        relative: stat.S_IMODE((state / relative).stat().st_mode)
        for relative in STATE_DIRECTORIES
    }
    print(
        "created directory modes:",
        {name: oct(mode) for name, mode in created_modes.items()},
    )
    print(
        "repaired directory modes:",
        {name: oct(mode) for name, mode in repaired_modes.items()},
    )
    assert set(created_modes.values()) == {0o750}, created_modes
    assert set(repaired_modes.values()) == {0o750}, repaired_modes
    # An unexpected group must fail before granting that group traversal.
    state.chmod(0o700)
    (root / "etc/group").write_text("root:x:0:\nwazuh:x:1:\n")
    try:
        run(SYSTEM_BIN / "chroot", root, bundle / "activate")
    except subprocess.CalledProcessError:
        pass
    else:
        raise AssertionError("Activation accepted state owned by the wrong group")
    assert stat.S_IMODE(state.stat().st_mode) == 0o700
    assert keys.read_text() == "synthetic-existing-key\n"
    (root / "etc/group").write_text("root:x:0:\nwazuh:x:0:\n")
    run(SYSTEM_BIN / "chroot", root, bundle / "activate")
    assert stat.S_IMODE(state.stat().st_mode) == 0o750
    print("PASS: immutable activation imports, creates state, and reactivates safely")


def main():
    if len(sys.argv) == 5 and sys.argv[1] == "--inside":
        inside(Path(sys.argv[2]), Path(sys.argv[3]), sys.argv[4])
        return
    if len(sys.argv) != 2 or os.geteuid() == 0:
        raise SystemExit("Run unprivileged with one immutable bundle path")
    bundle = Path(sys.argv[1]).resolve(strict=True)
    if bundle.parent != Path("/gnu/store") or not (bundle / "activate").is_file():
        raise SystemExit("Expected an immutable native service bundle")
    with tempfile.TemporaryDirectory(prefix="wazuh-activation-bundle-") as directory:
        root = Path(directory) / "root"
        root.mkdir()
        result = run(
            SYSTEM_BIN / "unshare",
            "--user",
            "--map-root-user",
            "--mount",
            "--pid",
            "--fork",
            "--kill-child",
            "--net",
            Path(sys.executable).resolve(),
            Path(__file__).resolve(),
            "--inside",
            bundle,
            root,
            Path("/proc/self/ns/mnt").readlink(),
        )
        print(result.stdout, end="")


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        print(error.stdout, end="", file=sys.stderr)
        print(error.stderr, end="", file=sys.stderr)
        raise SystemExit(error.returncode) from error
