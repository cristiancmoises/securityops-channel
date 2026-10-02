#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Exercise an installed-package sanity checker with synthetic metadata."""

from pathlib import Path
import subprocess
import sys
import tempfile


def main():
    checker = Path(sys.argv[1]).resolve()
    failures = []
    cases = [
        ("missing-dependency", "Requires-Dist: absent-sanity-dependency>=1\n",
         "fixture_module", "", "absent-sanity-dependency"),
        ("incompatible-version", "Requires-Dist: packaging>=999\n",
         "fixture_module", "", "packaging>=999"),
        ("broken-import", "", "absent_sanity_module", "", "absent_sanity_module"),
        ("broken-console-entry", "", "fixture_module",
         "[console_scripts]\nfixture = fixture_module:absent\n", "absent"),
        ("broken-gui-entry", "", "fixture_module",
         "[gui_scripts]\nfixture = fixture_module:absent\n", "absent"),
    ]
    with tempfile.TemporaryDirectory(prefix="sanity-fixtures-") as scratch:
        for name, requirements, top_level, entries, diagnostic in cases:
            root = Path(scratch) / name
            dist = root / "sanity_fixture-1.0.dist-info"
            dist.mkdir(parents=True)
            (dist / "METADATA").write_text(
                "Metadata-Version: 2.1\nName: sanity-fixture\nVersion: 1.0\n"
                + requirements)
            (dist / "top_level.txt").write_text(top_level + "\n")
            (dist / "entry_points.txt").write_text(entries)
            (root / "fixture_module.py").write_text("def main(): return 0\n")
            result = subprocess.run([sys.executable, str(checker), str(root)],
                                    text=True, capture_output=True, timeout=30)
            print(name, "exit", result.returncode, result.stdout, result.stderr,
                  flush=True)
            if result.returncode == 0 or diagnostic not in result.stdout + result.stderr:
                failures.append(name)
        root = Path(scratch) / "positive"
        dist = root / "sanity_fixture-1.0.dist-info"
        dist.mkdir(parents=True)
        (dist / "METADATA").write_text(
            "Metadata-Version: 2.1\nName: sanity-fixture\nVersion: 1.0\n"
            "Requires-Dist: packaging>=1,<999\n"
            "Requires-Dist: absent-sanity-optional; extra == 'optional'\n")
        (dist / "top_level.txt").write_text("fixture_module\n")
        (dist / "entry_points.txt").write_text(
            "[console_scripts]\nfixture = fixture_module:main\n"
            "[gui_scripts]\nfixture_gui = fixture_module:main\n")
        (root / "fixture_module.py").write_text("def main(): return 0\n")
        result = subprocess.run([sys.executable, str(checker), str(root)],
                                text=True, capture_output=True, timeout=30)
        print("positive", "exit", result.returncode, result.stdout, result.stderr,
              flush=True)
        if result.returncode != 0 or "sanity-fixture" not in result.stdout:
            failures.append("positive")
    assert not failures, failures


if __name__ == "__main__":
    main()
