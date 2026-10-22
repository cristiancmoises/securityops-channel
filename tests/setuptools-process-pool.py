"""Check the upstream test backend starts workers without inherited state.

Run with a path to the unpacked setuptools/tests/test_build_meta.py.
Only its two backend class definitions are loaded; no project imports run.
"""

import ast
import multiprocessing
import os
import sys
from collections.abc import Callable
from concurrent import futures
from pathlib import Path
from typing import Any

PARENT_STATE = False


def worker_state():
    return os.getpid(), PARENT_STATE


def main():
    global PARENT_STATE
    source = ast.parse(Path(sys.argv[1]).read_text())
    classes: list[ast.stmt] = [
        node
        for node in source.body
        if isinstance(node, ast.ClassDef)
        and node.name in {"BuildBackendBase", "BuildBackend"}
    ]
    assert len(classes) == 2, "upstream backend classes changed"
    namespace = {
        "futures": futures,
        "multiprocessing": multiprocessing,
        "Callable": Callable,
        "Any": Any,
    }
    # Exercise the reviewed upstream constructors, not a copy of their logic.
    exec(  # noqa: S102
        compile(ast.Module(body=classes, type_ignores=[]), sys.argv[1], "exec"),
        namespace,
    )
    backend = namespace["BuildBackend"]()
    PARENT_STATE = True
    try:
        worker_pid, inherited = backend.pool.submit(worker_state).result(timeout=15)
        assert worker_pid != os.getpid(), "backend ran in the parent"
        assert not inherited, "worker inherited parent state through fork"
    finally:
        backend.pool.shutdown(wait=True)
    print("backend worker starts fresh and shuts down successfully")


if __name__ == "__main__":
    main()
