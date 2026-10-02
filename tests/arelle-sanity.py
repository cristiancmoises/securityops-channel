#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Validate installed metadata, imports and script entry points without setuptools."""

import importlib
from importlib import metadata
from pathlib import Path
import sys

from packaging.requirements import Requirement
from packaging.specifiers import SpecifierSet


def check(site):
    site = Path(site).resolve()
    sys.path.insert(0, str(site))
    distributions = list(metadata.distributions(path=[str(site)]))
    if not distributions:
        raise RuntimeError(f"No installed distributions in {site}")
    visited = set()

    def requirements(dist, extras=frozenset()):
        key = (dist.metadata["Name"].lower(), frozenset(extras))
        if key in visited:
            return
        visited.add(key)
        python_range = dist.metadata.get("Requires-Python")
        if python_range and not SpecifierSet(python_range).contains(
                ".".join(map(str, sys.version_info[:3])), prereleases=True):
            raise RuntimeError(f"{key[0]} requires Python {python_range}")
        for raw in dist.requires or []:
            requirement = Requirement(raw)
            if requirement.marker and not any(
                    requirement.marker.evaluate({"extra": extra})
                    for extra in ("", *extras)):
                continue
            if requirement.url:
                raise RuntimeError(f"Cannot verify direct URL requirement: {raw}")
            try:
                dependency = metadata.distribution(requirement.name)
            except metadata.PackageNotFoundError as error:
                raise RuntimeError(f"Missing dependency: {raw}") from error
            if not requirement.specifier.contains(dependency.version,
                                                  prereleases=True):
                raise RuntimeError(f"Unsatisfied requirement: {raw}; installed {dependency.version}")
            print("Requirement:", raw, "installed", dependency.version, flush=True)
            requirements(dependency, requirement.extras)

    for dist in distributions:
        print("Validating", dist.metadata["Name"], dist.version, flush=True)
        requirements(dist)
        top_level = dist.read_text("top_level.txt")
        if not top_level or not top_level.strip():
            raise RuntimeError(f"Missing top-level import metadata: {dist.metadata['Name']}")
        for name in top_level.split():
            importlib.import_module(name)
            print("Imported:", name, flush=True)
        for entry in dist.entry_points:
            if entry.group in {"console_scripts", "gui_scripts"}:
                if not callable(entry.load()):
                    raise TypeError(f"Entry point is not callable: {entry.name}")
                print("Loaded entry point:", entry.group, entry.name, flush=True)


if __name__ == "__main__":
    check(sys.argv[1])
