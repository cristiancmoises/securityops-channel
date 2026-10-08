"""Exercise an installed DigiDoc4 in an unprivileged, isolated display."""

import argparse
import json
import os
import shutil
import subprocess
import tempfile
import time
import zipfile
from pathlib import Path


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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("desktop", type=Path)
    parser.add_argument("state", type=Path)
    args = parser.parse_args()
    assert os.getuid() != 0
    assert {entry.name for entry in Path("/sys/class/net").iterdir()} == {"lo"}
    assert str(args.desktop.resolve()).startswith("/gnu/store/")
    bootstrap = args.desktop / "share/digidoc4/bootstrap"
    metadata = json.loads((bootstrap / "config.json").read_text())["META-INF"]
    assert metadata["SERIAL"] == 212
    with tempfile.TemporaryDirectory(prefix="digidoc4-", dir=args.state) as name:
        private = Path(name)
        run(
            "openssl",
            "base64",
            "-d",
            "-in",
            str(bootstrap / "config.ecc"),
            "-out",
            str(private / "signature.der"),
        )
        verification = (
            "openssl",
            "dgst",
            "-sha512",
            "-verify",
            str(bootstrap / "config.ecpub"),
            "-signature",
            str(private / "signature.der"),
        )
        assert "Verified OK" in run(*verification, str(bootstrap / "config.json"))
        invalid = private / "invalid-config.json"
        invalid.write_text('{"META-INF":{"SERIAL":999}}')
        result = subprocess.run(
            [*verification, str(invalid)], capture_output=True, timeout=25, check=False
        )
        assert result.returncode != 0, "altered configuration was trusted"
        print("PASS: installed bootstrap signature, serial and tamper rejection")
        valid = private / "unsigned-fixture.asice"
        with zipfile.ZipFile(valid, "w") as archive:
            archive.writestr("mimetype", "application/vnd.etsi.asic-e+zip")
            archive.writestr("payload.txt", "DigiDoc4 local unsigned fixture\n")
            archive.writestr(
                "META-INF/manifest.xml",
                '<?xml version="1.0" encoding="UTF-8"?>'
                '<manifest:manifest xmlns:manifest="'
                'urn:oasis:names:tc:opendocument:xmlns:manifest:1.0">'
                '<manifest:file-entry manifest:full-path="/" '
                'manifest:media-type="application/vnd.etsi.asic-e+zip"/>'
                '<manifest:file-entry manifest:full-path="payload.txt" '
                'manifest:media-type="text/plain"/></manifest:manifest>',
            )
        malformed = private / "invalid-fixture.asice"
        malformed.write_text("not a document container\n")
        for document in (valid, malformed):
            case = private / document.stem
            case.mkdir(mode=0o700)
            environment = dict(os.environ)
            for variable in (
                "HOME",
                "TMPDIR",
                "XDG_CONFIG_HOME",
                "XDG_DATA_HOME",
                "XDG_CACHE_HOME",
                "XDG_RUNTIME_DIR",
            ):
                folder = case / variable.lower()
                folder.mkdir(mode=0o700)
                environment[variable] = str(folder)
            cache = Path(environment["XDG_DATA_HOME"]) / "RIA/qdigidoc4"
            cache.mkdir(parents=True)
            shutil.copyfile(bootstrap / "config.ecc", cache / "config.ecc")
            (cache / "config.json").write_text(
                '{"META-INF":{"SERIAL":999},"QDIGIDOC4-UNSUPPORTED":"999.0"}'
            )
            environment["LANG"] = "en_US.utf8"
            environment["QT_QPA_PLATFORM"] = "xcb"
            with (case / "xvfb.log").open("w+") as display_log:
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
                    assert number.isdigit(), "private display did not start"
                    environment["DISPLAY"] = ":" + number
                    with (case / "desktop.log").open("w+") as desktop_log:
                        desktop = subprocess.Popen(
                            [str(args.desktop / "bin/qdigidoc4"), str(document)],
                            env=environment,
                            stdout=desktop_log,
                            stderr=subprocess.STDOUT,
                        )
                        try:
                            deadline = time.monotonic() + 90
                            while True:
                                assert desktop.poll() is None, "desktop exited early"
                                search = subprocess.run(
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
                                if search.returncode == 0:
                                    break
                                assert time.monotonic() < deadline, "no visible desktop"
                                time.sleep(0.2)
                            time.sleep(5)
                            # Close the informational first-run tour through
                            # its normal keyboard action, not a preference
                            # override.  Document handling must be visible.
                            run("xdotool", "key", "Escape", env=environment)
                            deadline = time.monotonic() + 300
                            while (
                                "TSL loading finished"
                                not in (case / "desktop.log").read_text()
                            ):
                                assert desktop.poll() is None, "desktop exited early"
                                assert time.monotonic() < deadline, (
                                    "signed trust-list initialization did not finish"
                                )
                                time.sleep(0.25)
                            time.sleep(3)
                            assert (cache / "config.json").read_bytes() == (
                                bootstrap / "config.json"
                            ).read_bytes(), (
                                "desktop trusted tampered cached configuration"
                            )
                            print(
                                "PASS: actual desktop rejected and replaced tampered cache"
                            )
                            windows = run("xwininfo", "-root", "-tree", env=environment)
                            assert "DigiDoc" in windows or "qdigidoc" in windows, (
                                windows
                            )
                            print("WINDOWS:", document.name, windows)
                            maps = Path(f"/proc/{desktop.pid}/maps").read_text()
                            for version in (
                                "libdigidocpp-4.5.1",
                                "openssl-3.5.9",
                                "libxml2-2.15.4",
                                "libxslt-1.1.45",
                                "qtbase-6.9.2",
                            ):
                                assert version in maps, version
                            run(
                                "import",
                                "-window",
                                "root",
                                str(args.state / (document.stem + ".png")),
                                env=environment,
                            )
                            print(
                                "PASS: visible desktop and matching loaded libraries",
                                document.name,
                            )
                        finally:
                            stop(desktop)
                            desktop_log.seek(0)
                            (args.state / (document.stem + ".log")).write_text(
                                desktop_log.read()
                            )
                finally:
                    stop(display)
    print("PASS: isolated desktop checks; document screenshots require inspection")


if __name__ == "__main__":
    main()
