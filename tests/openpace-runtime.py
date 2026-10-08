"""Check OpenPACE layout and benign installed APIs; no card/provider is used.

Functional mode requires an unprivileged, network-isolated Guix container with
only these fixtures exposed read-only, plus Python, GCC, binutils and pkg-config.
"""

import argparse
import hashlib
import os
import resource
import shlex
import shutil
import subprocess
import tempfile
from pathlib import Path

SOURCE_HASH = "fae7f8cb9fa8955cbb4496db1a592a8481bad56dc98f81379661b07e39be4e08"
COPYING_HASH = "0a4eb9f09317bb6e277ef320df907193e5871bf70fad3bf27d492c131c48be08"
PERMISSIONS_HASH = "d7d657a1e7ec1cf49c043b6ed2e79bd61bf7d34a47ada887fa4048af0f41903f"
CRYPTO_SOURCE_HASH = "603f5602e2eef00d77fbd429d34dcd5822bb301757a1bc9cdb24c670f1eb859a"
CRYPTO_EFFECTIVE_SOURCE_HASH = (
    "f1c0bd55cbc0ca66db66357336a464bb2ec2430e7b5514c6ad2e445c87091ba8"
)
EXAMPLES = {
    "cvc/DECVCAeID00102": "b97b252dd4beea03a9e9feba8ed021cbdc7c31b26eedf9ab80509198e09bea59",
    "cvc/DECVCAEPASS00102": "4362155fb9db80d19519a8af68db7362984f2e76004e5128c370d5f888290464",
    "cvc/DECVCAeSign00102": "e808f543586dcae9f3f4265374f79555ed587ffe1b46a60b2b121f9b33c5f031",
    "x509/ff3d20d2": "e15ea42388498587f518cb2ab07e9e4acd5c4a2f8d3cfcc839d52a6b070631a5",
}


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def check_layout(prefix: Path) -> None:
    assert prefix.is_dir(), "installed OpenPACE output is missing"
    assert prefix.parent == Path("/gnu/store") and prefix.name.endswith(
        "-openpace-1.1.4"
    )
    share = prefix / "share/openpace"
    for kind in ("cvc", "x509"):
        directory = share / "trust" / kind
        assert directory.is_dir() and not list(directory.iterdir()), (
            "compiled default trust directory must be empty",
            kind,
        )
        assert directory.stat().st_mode & 0o222 == 0, "default roots must be immutable"
    examples = share / "examples"
    assert sorted(
        str(path.relative_to(examples))
        for path in examples.rglob("*")
        if path.is_file()
    ) == sorted(EXAMPLES), "exactly the four original examples must be retained"
    for relative, expected in EXAMPLES.items():
        assert digest(examples / relative) == expected, relative
    assert digest(share / "source/openpace-1.1.4.tar.gz") == SOURCE_HASH
    assert digest(prefix / "share/doc/openpace/COPYING") == COPYING_HASH
    assert (
        digest(prefix / "share/doc/openpace/license-source/eac.h") == PERMISSIONS_HASH
    )
    assert digest(share / "source/openssl-3.5.9.tar.gz") == CRYPTO_SOURCE_HASH
    assert (
        digest(share / "source/openssl-3.5.9-guix-patched.tar.zst")
        == CRYPTO_EFFECTIVE_SOURCE_HASH
    )
    for name, magic in (
        ("openssl-3.5.9.tar.gz", bytes.fromhex("1f8b")),
        ("openssl-3.5.9-guix-patched.tar.zst", bytes.fromhex("28b52ffd")),
    ):
        with (share / "source" / name).open("rb") as stream:
            assert stream.read(len(magic)) == magic, (
                "wrong source archive format",
                name,
            )
    for header in ("eac.h", "cv_cert.h", "pace.h", "ca.h", "ta.h", "ri.h"):
        assert (prefix / "include/eac" / header).is_file(), header
    for executable in ("eactest", "cvc-create", "cvc-print", "example"):
        assert os.access(prefix / "bin" / executable, os.X_OK), executable
    assert (prefix / "lib/libeac.so.3").is_file(), "installed native SONAME is missing"
    assert (prefix / "lib/pkgconfig/libeac.pc").is_file()
    assert not (prefix / "lib/python").exists(), (
        "optional language bindings are not selected"
    )
    print(
        "PASS: exact source/notices/examples, native headers/tools and empty immutable default roots"
    )


def limits() -> None:
    for option, maximum in (
        (resource.RLIMIT_AS, 1024 * 1024 * 1024),
        (resource.RLIMIT_NPROC, 64),
        (resource.RLIMIT_FSIZE, 64 * 1024 * 1024),
        (resource.RLIMIT_CPU, 120),
        (resource.RLIMIT_CORE, 0),
    ):
        resource.setrlimit(option, (maximum, maximum))


def command(argv: list[str], cwd: Path, env: dict[str, str]) -> str:
    print("RUN:", shlex.join(argv), flush=True)
    result = subprocess.run(
        argv,
        cwd=cwd,
        env=env,
        capture_output=True,
        text=True,
        timeout=180,
        check=False,
        preexec_fn=limits,
    )
    print(result.stdout, end="", flush=True)
    print(result.stderr, end="", flush=True)
    assert result.returncode == 0, (argv[0], result.returncode)
    return result.stdout


def development_environment(names: tuple[str, ...]) -> dict[str, str]:
    profile = Path(os.environ["GUIX_ENVIRONMENT"])
    resolved = profile.resolve()
    assert resolved.parent == Path("/gnu/store")
    paths: dict[str, str] = {}
    for name in names:
        value = os.environ.get(name)
        assert value, f"missing Guix-generated development search path: {name}"
        assert all(
            ".." not in Path(item).parts
            and (
                Path(item).is_relative_to(profile)
                or Path(item).is_relative_to(resolved)
            )
            for item in value.split(":")
        ), ("development paths must stay in this exact merged profile", name)
        paths[name] = value
    return paths


def check_runtime(prefix: Path, crypto: Path, probe: Path) -> None:
    assert os.getuid() != 0, "functional tests require an unprivileged account"
    assert {path.name for path in Path("/sys/class/net").iterdir()} == {"lo"}, (
        "functional tests require a private offline network namespace"
    )
    assert crypto.parent == Path("/gnu/store") and crypto.name.endswith(
        "-openssl-3.5.9"
    )
    tools: dict[str, Path] = {}
    for name in ("gcc", "pkg-config", "readelf"):
        found = shutil.which(name)
        assert found, f"missing native test tool: {name}"
        tool = Path(found).resolve()
        assert tool.is_relative_to("/gnu/store"), (
            "native test tool must be immutable",
            tool,
        )
        tools[name] = tool
    with tempfile.TemporaryDirectory(prefix="openpace-cardless-") as temporary:
        work = Path(temporary)
        work.chmod(0o700)
        roots = work / "operator-cvc"
        roots.mkdir(mode=0o700)
        shutil.copyfile(
            prefix / "share/openpace/examples/cvc/DECVCAeID00102",
            roots / "DECVCAeID00102",
        )
        env = {
            "HOME": str(work),
            "TMPDIR": str(work),
            "PATH": ":".join(sorted({str(tool.parent) for tool in tools.values()})),
            "LANG": "C.UTF-8",
            "LC_ALL": "C.UTF-8",
            "TZ": "UTC",
            "PKG_CONFIG_LIBDIR": f"{prefix}/lib/pkgconfig:{crypto}/lib/pkgconfig",
        }
        env.update(development_environment(("C_INCLUDE_PATH", "LIBRARY_PATH")))
        # Only the two explicit immutable package roots supply metadata.
        # Native compiler headers/libraries come only from this Guix profile;
        # no ambient loader/provider overrides are inherited.
        pkg_config = str(tools["pkg-config"])
        assert (
            command([pkg_config, "--modversion", "libeac"], work, env).strip()
            == "1.1.4"
        )
        for kind in ("cvc", "x509"):
            assert command(
                [pkg_config, f"--variable={kind}dir", "libeac"], work, env
            ).strip() == str(prefix / "share/openpace/trust" / kind)
        assert command(
            [pkg_config, "--variable=prefix", "libcrypto"], work, env
        ).strip() == str(crypto)
        flags = shlex.split(
            command([pkg_config, "--cflags", "--libs", "libeac"], work, env)
        )
        executable = work / "lifecycle"
        command(
            [
                str(tools["gcc"]),
                "-Wall",
                "-Wextra",
                "-Werror",
                str(probe),
                "-o",
                str(executable),
            ]
            + flags
            + ["-ldl", f"-Wl,-rpath,{prefix}/lib", f"-Wl,-rpath,{crypto}/lib"],
            work,
            env,
        )
        dynamic = command(
            [str(tools["readelf"]), "-d", str(prefix / "lib/libeac.so.3")], work, env
        )
        assert "[libeac.so.3]" in dynamic and "[libcrypto.so.3]" in dynamic
        assert str(crypto / "lib") in dynamic, (
            "runtime crypto binding must be package-scoped"
        )
        output = command([str(executable), str(roots)], work, env)
        assert f"EAC_LIBRARY={prefix}/lib/libeac.so.3" in output
        assert f"CRYPTO_LIBRARY={crypto}/lib/libcrypto.so.3" in output
        assert "CRYPTO_VERSION=OpenSSL 3.5.9 " in output
        assert (
            "PASS: cardless context lifecycle; empty default and explicit original-example lookup"
            in output
        )
        output = command([str(prefix / "bin/eactest")], work, env)
        assert "Everything works as expected." in output, (
            "original installed eactest must pass"
        )
        for name in ("cvc-create", "cvc-print"):
            command([str(prefix / "bin" / name), "--help"], work, env)
    print(
        "PASS: installed ELF/SONAME/pkg-config, actual loaded libEAC/crypto and original eactest; no card/provider"
    )


def check_consumer(prefix: Path, probe: Path) -> None:
    """Use only development search paths generated by the merged Guix profile."""
    assert os.getuid() != 0, "consumer tests require an unprivileged account"
    assert {path.name for path in Path("/sys/class/net").iterdir()} == {"lo"}, (
        "consumer tests require a private offline network namespace"
    )
    profile = Path(os.environ["GUIX_ENVIRONMENT"])
    assert profile.resolve().parent == Path("/gnu/store")
    tools = [profile / "bin" / name for name in ("gcc", "pkg-config")]
    assert all(tool.resolve().is_relative_to("/gnu/store") for tool in tools)
    with tempfile.TemporaryDirectory(prefix="openpace-consumer-") as temporary:
        work = Path(temporary)
        work.chmod(0o700)
        env = {
            "PATH": str(profile / "bin"),
            "HOME": str(work),
            "TMPDIR": str(work),
            "LANG": "C.UTF-8",
            "LC_ALL": "C.UTF-8",
            "TZ": "UTC",
        }
        # These are generated by guix shell from its actual merged profile,
        # not invented per-package include/library/pkg-config paths.
        env.update(
            development_environment(
                ("PKG_CONFIG_PATH", "C_INCLUDE_PATH", "LIBRARY_PATH")
            )
        )
        pkg_config = str(tools[1])
        assert (
            command([pkg_config, "--modversion", "libeac"], work, env).strip()
            == "1.1.4"
        )
        crypto = Path(
            command([pkg_config, "--variable=prefix", "libcrypto"], work, env).strip()
        )
        assert crypto.parent == Path("/gnu/store") and crypto.name.endswith(
            "-openssl-3.5.9"
        )
        flags = shlex.split(
            command([pkg_config, "--cflags", "--libs", "libeac"], work, env)
        )
        executable = work / "consumer"
        command(
            [
                str(tools[0]),
                "-Wall",
                "-Wextra",
                "-Werror",
                str(probe),
                "-o",
                str(executable),
            ]
            + flags
            + ["-ldl"],
            work,
            env,
        )
        roots = work / "operator-cvc"
        roots.mkdir(mode=0o700)
        shutil.copyfile(
            prefix / "share/openpace/examples/cvc/DECVCAeID00102",
            roots / "DECVCAeID00102",
        )
        output = command([str(executable), str(roots)], work, env)
        assert f"EAC_LIBRARY={prefix}/lib/libeac.so.3" in output
        assert f"CRYPTO_LIBRARY={crypto}/lib/libcrypto.so.3" in output
        assert "CRYPTO_VERSION=OpenSSL 3.5.9 " in output
        assert (
            "PASS: cardless context lifecycle; empty default and explicit original-example lookup"
            in output
        )
    print(
        "PASS: real downstream compile/link/lifecycle from OpenPACE-only dependency selection; no explicit crypto or PKG_CONFIG_LIBDIR"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("prefix", type=Path)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--runtime", action="store_true")
    modes.add_argument("--consumer", action="store_true")
    parser.add_argument("--probe", type=Path)
    parser.add_argument("--crypto", type=Path)
    args = parser.parse_args()
    prefix = args.prefix.resolve()
    check_layout(prefix)
    if args.runtime:
        assert args.probe is not None, (
            "functional tests require the exact read-only C probe"
        )
        assert args.crypto is not None, (
            "functional tests require the explicit installed crypto dependency"
        )
        check_runtime(prefix, args.crypto.resolve(), args.probe.resolve())
    if args.consumer:
        assert args.probe is not None, (
            "consumer tests require the exact read-only C probe"
        )
        assert args.crypto is None, (
            "consumer tests must not select a crypto dependency explicitly"
        )
        check_consumer(prefix, args.probe.resolve())


if __name__ == "__main__":
    main()
