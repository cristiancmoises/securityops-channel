#!/usr/bin/env python3
"""Fail-closed capacity guard for the private build-farm CT on Proxmox."""

import re
import subprocess
import sys
from pathlib import Path

CT_ID = "126"
REGISTER_UNIT = "securityops-cuirass-register.service"
PAUSE_FILE = Path("/var/lib/securityops-build-farm/PAUSED")
MIN_MEMORY_KIB = 4 * 1024**2


def pause_reasons(thin_percent, disk_percent, available_kib):
    values = (thin_percent, disk_percent)
    if any(not isinstance(v, (int, float)) or not 0 <= v <= 100 for v in values):
        raise ValueError("invalid capacity percentage")
    if not isinstance(available_kib, int) or available_kib < 0:
        raise ValueError("invalid available memory")
    reasons = []
    if thin_percent >= 80:
        reasons.append("thin-pool")
    if disk_percent >= 85:
        reasons.append("builder-disk")
    if available_kib < MIN_MEMORY_KIB:
        reasons.append("host-memory")
    return reasons


def decide_action(reasons, already_paused):
    if already_paused:
        return "remain-paused" if reasons else "resume"
    return "pause" if reasons else "continue"


def parse_lvs(output):
    parts = output.split()
    if len(parts) != 1:
        raise ValueError("unexpected lvs output")
    try:
        value = float(parts[0])
    except ValueError as error:
        raise ValueError("invalid lvs percentage") from error
    if not 0 <= value <= 100:
        raise ValueError("lvs percentage out of range")
    return value


def parse_df(output):
    rows = output.strip().splitlines()
    if len(rows) != 2:
        raise ValueError("unexpected df output")
    fields = rows[1].split()
    if len(fields) != 6 or fields[-1] != "/" or not re.fullmatch(r"\d+%", fields[4]):
        raise ValueError("invalid root filesystem usage")
    value = float(fields[4][:-1])
    if not 0 <= value <= 100:
        raise ValueError("root filesystem percentage out of range")
    return value


def parse_meminfo(output):
    match = re.search(r"^MemAvailable:\s+(\d+)\s+kB$", output, re.MULTILINE)
    if match is None:
        raise ValueError("MemAvailable missing")
    return int(match.group(1))


def command(*args):
    return subprocess.run(
        args, check=True, text=True, capture_output=True, timeout=20
    ).stdout


def collect_metrics():
    thin = parse_lvs(
        command("lvs", "--noheadings", "--nosuffix", "-o", "data_percent", "pve/data")
    )
    disk = parse_df(command("pct", "exec", CT_ID, "--", "df", "-P", "/"))
    memory = parse_meminfo(Path("/proc/meminfo").read_text(encoding="ascii"))
    return thin, disk, memory


def pause(reason):
    PAUSE_FILE.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    PAUSE_FILE.write_text(reason + "\n", encoding="utf-8")
    stop_registration()


def stop_registration():
    command("pct", "exec", CT_ID, "--", "systemctl", "disable", "--now", REGISTER_UNIT)


def resume():
    command("pct", "exec", CT_ID, "--", "systemctl", "enable", "--now", REGISTER_UNIT)
    PAUSE_FILE.unlink()


def main():
    already_paused = PAUSE_FILE.exists()
    try:
        metrics = collect_metrics()
        reasons = pause_reasons(*metrics)
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        reasons = ["metric-error:" + type(error).__name__]
    action = decide_action(reasons, already_paused)
    if action == "pause":
        print("PAUSE build farm: " + ", ".join(reasons), file=sys.stderr)
        try:
            pause(", ".join(reasons))
        except (OSError, subprocess.SubprocessError) as error:
            print(
                "Unable to stop registration: " + type(error).__name__, file=sys.stderr
            )
            return 2
        return 1
    if action == "remain-paused":
        try:
            stop_registration()
        except (OSError, subprocess.SubprocessError) as error:
            print(
                "Unable to stop registration: " + type(error).__name__, file=sys.stderr
            )
            return 2
        print("Build farm remains manually paused", file=sys.stderr)
        return 1
    if action == "resume":
        try:
            resume()
        except (OSError, subprocess.SubprocessError) as error:
            print(
                "Unable to resume registration: " + type(error).__name__,
                file=sys.stderr,
            )
            return 2
        print("Build farm capacity recovered; registration resumed")
        return 0
    print("Build farm capacity OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
