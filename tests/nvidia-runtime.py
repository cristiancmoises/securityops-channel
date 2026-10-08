#!/usr/bin/env python3
"""Check the installed matched stack without exposing or initializing a GPU."""

import argparse
import ctypes
import json
import os
import subprocess
from pathlib import Path


def output(*command: str) -> str:
    return subprocess.check_output(command, text=True, timeout=30).strip()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("driver", type=Path)
    parser.add_argument("firmware", type=Path)
    parser.add_argument("module", type=Path)
    parser.add_argument("union", type=Path)
    parser.add_argument("version")
    parser.add_argument("kernel")
    args = parser.parse_args()
    assert os.getuid() != 0, "use an unprivileged test user"
    assert {path.name for path in Path("/sys/class/net").iterdir()} == {"lo"}
    assert not list(Path("/dev").glob("nvidia*")), "do not expose GPU devices"

    library = args.driver / "lib" / f"libnvidia-ml.so.{args.version}"
    assert library.is_file(), "driver unpack must use the new installer"
    nvml = ctypes.CDLL(str(library))
    nvml.nvmlSystemGetNVMLVersion.argtypes = [ctypes.c_void_p, ctypes.c_uint]
    nvml.nvmlSystemGetNVMLVersion.restype = ctypes.c_int
    buffer = ctypes.create_string_buffer(256)
    # This metadata API works without nvmlInit; never initialize a GPU/driver.
    assert nvml.nvmlSystemGetNVMLVersion(buffer, len(buffer)) == 0
    nvml_version = buffer.value.decode()
    assert args.version in nvml_version, nvml_version
    print("NVML library metadata:", nvml_version)

    for name in ("libcuda.so.1", "libnvidia-ml.so.1", "libGLX_nvidia.so.0"):
        resolved = (args.driver / "lib" / name).resolve(strict=True)
        assert args.version in resolved.name, resolved
        assert (args.driver / "lib" / resolved.name).samefile(resolved), resolved
        links = output("ldd", str(resolved))
        print(name, links)
        assert "not found" not in links
        union_library = args.union / "lib" / name
        assert union_library.samefile(resolved)

    for directory in (
        "share/vulkan/icd.d",
        "share/glvnd/egl_vendor.d",
        "share/egl/egl_external_platform.d",
    ):
        descriptors = list((args.driver / directory).glob("*.json"))
        assert descriptors, ("missing graphics provider descriptors", directory)
        for filename in descriptors:
            value = json.loads(filename.read_text())
            library_path = value["ICD"]["library_path"]
            referenced = Path(library_path)
            assert referenced.is_absolute(), (filename, library_path)
            assert referenced.is_file(), (filename, library_path)
            print("ICD library:", filename.relative_to(args.driver), referenced)

    firmware = args.firmware / "lib/firmware/nvidia" / args.version
    assert firmware.is_dir(), "firmware must be installed under the matched release"
    assert {path.name for path in firmware.iterdir()} >= {
        "gsp_ga10x.bin",
        "gsp_tu10x.bin",
        "ucodes_ga10x.bin",
        "ucodes_tu10x.bin",
    }
    assert all(path.stat().st_size > 0 for path in firmware.glob("*.bin"))
    print("Matched firmware:", sorted(path.name for path in firmware.iterdir()))

    modules = {
        path.name.removesuffix(".zst").removesuffix(".xz").removesuffix(".gz"): path
        for path in args.module.glob("lib/modules/**/*.ko*")
        if path.suffix in {".ko", ".zst", ".xz", ".gz"}
    }
    for name in (
        "nvidia.ko",
        "nvidia-modeset.ko",
        "nvidia-drm.ko",
        "nvidia-uvm.ko",
        "nvidia-peermem.ko",
    ):
        module = modules[name]
        version = output("modinfo", "-F", "version", str(module))
        vermagic = output("modinfo", "-F", "vermagic", str(module))
        assert version == args.version, (name, version)
        assert vermagic.split()[0] == args.kernel, (name, vermagic)
        print("Kernel module:", name, version, vermagic)
    print("PASS: matched libraries, firmware, module ABI and union; no GPU activation")


if __name__ == "__main__":
    main()
