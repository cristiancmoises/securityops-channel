#!/usr/bin/env python3
"""Check an installed Belgian eID provider and viewer without a card or service."""

import argparse
import ctypes
import os
import shutil
import subprocess
import tempfile
import time
from pathlib import Path


class Version(ctypes.Structure):
    _fields_ = [("major", ctypes.c_ubyte), ("minor", ctypes.c_ubyte)]


class Info(ctypes.Structure):
    _fields_ = [
        ("cryptoki", Version),
        ("manufacturer", ctypes.c_char * 32),
        ("flags", ctypes.c_ulong),
        ("description", ctypes.c_char * 32),
        ("library", Version),
    ]


def run(*arguments, env=None):
    return subprocess.run(
        arguments, env=env, capture_output=True, text=True, timeout=25, check=True
    ).stdout


def stop(process):
    if process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=10)


def provider(root):
    library = root / "lib/libbeidpkcs11.so"
    assert "not found" not in run("ldd", str(library))
    native = ctypes.CDLL(str(library))
    for name in ("C_Initialize", "C_Finalize", "C_GetInfo", "C_GetFunctionList"):
        function = getattr(native, name)
        function.argtypes = [ctypes.c_void_p]
        function.restype = ctypes.c_ulong
    native.C_GetSlotList.argtypes = [
        ctypes.c_ubyte,
        ctypes.c_void_p,
        ctypes.POINTER(ctypes.c_ulong),
    ]
    native.C_GetSlotList.restype = ctypes.c_ulong
    assert native.C_Finalize(None) == 0x190  # CKR_CRYPTOKI_NOT_INITIALIZED
    functions = ctypes.c_void_p()
    assert native.C_GetFunctionList(ctypes.byref(functions)) == 0 and functions.value
    assert native.C_Initialize(None) == 0
    try:
        assert native.C_Initialize(None) == 0x191  # CKR_CRYPTOKI_ALREADY_INITIALIZED
        assert native.C_GetInfo(None) == 7  # CKR_ARGUMENTS_BAD
        info = Info()
        assert native.C_GetInfo(ctypes.byref(info)) == 0
        assert (info.cryptoki.major, info.cryptoki.minor) == (2, 40)
        assert (info.library.major, info.library.minor) == (5, 1)
        assert "Belgium" in info.description.decode()
        print("Provider:", info.manufacturer.decode(), info.description.decode())
        count = ctypes.c_ulong(999)
        assert native.C_GetSlotList(0, None, ctypes.byref(count)) == 0
        assert count.value == 0, "unexpected card reader in isolated fixture"
    finally:
        assert native.C_Finalize(None) == 0
    assert native.C_Finalize(None) == 0x190
    print("PASS: installed PKCS11 function table, metadata, lifecycle and empty slots")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("middleware", type=Path)
    parser.add_argument("state", type=Path)
    args = parser.parse_args()
    assert os.getuid() != 0
    assert {entry.name for entry in Path("/sys/class/net").iterdir()} == {"lo"}
    assert not Path("/run/pcscd").exists()
    assert str(args.middleware.resolve()).startswith("/gnu/store/")
    with tempfile.TemporaryDirectory(prefix="belgian-eid-", dir=args.state) as name:
        private = Path(name)
        environment = dict(os.environ)
        for variable in (
            "HOME",
            "TMPDIR",
            "XDG_CONFIG_HOME",
            "XDG_DATA_HOME",
            "XDG_CACHE_HOME",
            "XDG_RUNTIME_DIR",
        ):
            folder = private / variable.lower()
            folder.mkdir(mode=0o700)
            environment[variable] = str(folder)
        os.environ.update(environment)
        environment["LANG"] = "C.UTF-8"
        provider(args.middleware)
        viewer = args.middleware / "bin/eid-viewer"
        binary = args.middleware / "bin/.eid-viewer-real"
        assert b"\x005.1.31\x00" in binary.read_bytes(), "wrong embedded release"
        with (private / "xvfb.log").open("w+") as display_log:
            display = subprocess.Popen(
                [
                    "Xvfb",
                    "-displayfd",
                    "1",
                    "-screen",
                    "0",
                    "1280x900x24",
                    "-nolisten",
                    "tcp",
                ],
                env=environment,
                stdout=subprocess.PIPE,
                stderr=display_log,
            )
            try:
                assert display.stdout is not None
                number = display.stdout.readline().decode().strip()
                assert number.isdigit()
                environment["DISPLAY"] = ":" + number
                with (private / "viewer.log").open("w+") as viewer_log:
                    desktop = subprocess.Popen(
                        [str(viewer)],
                        env=environment,
                        stdout=viewer_log,
                        stderr=subprocess.STDOUT,
                    )
                    try:
                        deadline = time.monotonic() + 60
                        while True:
                            assert desktop.poll() is None, "viewer exited early"
                            windows = subprocess.run(
                                [
                                    "xdotool",
                                    "search",
                                    "--onlyvisible",
                                    "--pid",
                                    str(desktop.pid),
                                ],
                                env=environment,
                                capture_output=True,
                                text=True,
                                timeout=10,
                                check=False,
                            )
                            if windows.returncode == 0:
                                break
                            assert time.monotonic() < deadline, "no visible viewer"
                            time.sleep(0.2)
                        time.sleep(2)
                        maps = Path(f"/proc/{desktop.pid}/maps").read_text()
                        for dependency in (
                            "eid-mw-5.1.31",
                            "openssl-3.5.9",
                            "libxml2-2.15.4",
                            "gtk+-3.24.52",
                        ):
                            assert dependency in maps, dependency
                        titles = [
                            run(
                                "xdotool", "getwindowname", window, env=environment
                            ).strip()
                            for window in windows.stdout.split()
                        ]
                        assert "eid-viewer" in titles, titles
                        print("Viewer windows:", titles)
                        run(
                            "import",
                            "-window",
                            "root",
                            str(args.state / "belgian-eid-viewer.png"),
                            env=environment,
                        )
                        window = windows.stdout.split()[0]
                        run("xdotool", "windowfocus", window, env=environment)
                        run(
                            "xdotool",
                            "mousemove",
                            "--window",
                            window,
                            "63",
                            "12",
                            "click",
                            "1",
                            env=environment,
                        )
                        time.sleep(0.2)
                        run(
                            "xdotool",
                            "mousemove",
                            "--window",
                            window,
                            "87",
                            "37",
                            env=environment,
                        )
                        time.sleep(0.2)
                        run("xdotool", "mousedown", "1", env=environment)
                        time.sleep(0.2)
                        run("xdotool", "mouseup", "1", env=environment)
                        time.sleep(1)
                        run(
                            "import",
                            "-window",
                            "root",
                            str(args.state / "belgian-eid-about.png"),
                            env=environment,
                        )
                        about = run(
                            "xdotool",
                            "search",
                            "--onlyvisible",
                            "--name",
                            "About",
                            env=environment,
                        )
                        assert about.strip(), "About dialog did not open"
                        assert desktop.poll() is None
                        print("PASS: GTK3 viewer and current native library maps")
                        print("Screenshot requires visual inspection; no card, PIN,")
                        print(
                            "signature, browser registration or host service was tested."
                        )
                    finally:
                        stop(desktop)
            finally:
                stop(display)
                shutil.copyfile(private / "xvfb.log", args.state / "xvfb.log")
                if (private / "viewer.log").exists():
                    shutil.copyfile(private / "viewer.log", args.state / "viewer.log")


if __name__ == "__main__":
    main()
