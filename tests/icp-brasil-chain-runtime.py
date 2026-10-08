#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Check installed ICP-Brasil CA data without registering certificate trust."""

import argparse
import hashlib
import json
import os
import re
import socket
import ssl
import subprocess
import zipfile
from collections import Counter
from pathlib import Path

MANIFEST_SHA256 = "c2e445e9c1bfde1a831a8d211b8be338e403a8f8471c788b22613349663d8427"
NOTICE_SHA256 = "565070af82e3630bf839392ee9d32d505497bee5fd9cb698114fc10c0865fca4"
ARCHIVE_SHA256 = "d7f977c68fed76090dc58c32684716f4a8863bb94cb2d9fd663328c01eeaaf7d"
ARCHIVE_SHA512 = (
    "4585a99955607525e475cf22138302fe8ddce6ca8f0926cd1f01809f007d4bcddff"
    "5c1070369d29b1de99c0d2eb058ce0deb856bae0189469ba37e09a59d7985"
)
SOURCE_URL = (
    "https://www.gov.br/iti/pt-br/assuntos/repositorio/"
    "certificados-das-acs-da-icp-brasil-arquivo-unico-compactado"
)
ED521 = "1.3.6.1.4.1.44588.2.1"


def native(openssl: Path, *arguments: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(openssl), *arguments],
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        timeout=15,
        check=False,
    )


def check_archive(archive: Path, originals: dict[str, bytes]) -> None:
    raw = archive.read_bytes()
    assert len(raw) == 351321
    assert hashlib.sha256(raw).hexdigest() == ARCHIVE_SHA256
    assert hashlib.sha512(raw).hexdigest() == ARCHIVE_SHA512
    with zipfile.ZipFile(archive) as source:
        entries = source.infolist()
        assert len(entries) == 180
        assert sum(entry.file_size for entry in entries) == 451012
        assert {entry.filename for entry in entries} == set(originals)
        for entry in entries:
            assert not entry.is_dir() and entry.file_size <= 4096
            assert source.read(entry) == originals[entry.filename], entry.filename
    print("PASS source ZIP: official SHA-512 and all 180 byte-identical original PEMs")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package", type=Path)
    parser.add_argument("openssl", type=Path)
    parser.add_argument("--source-archive", type=Path)
    parser.add_argument("--isolated", action="store_true")
    args = parser.parse_args()
    if args.isolated:
        assert os.geteuid() != 0, "isolated data check must be unprivileged"
        assert {name for _, name in socket.if_nameindex()} == {"lo"}
        print("PASS unprivileged network namespace: loopback only")
    share = args.package / "share/icp-brasil-ca-data"
    manifest_file = share / "manifest.json"
    assert manifest_file.stat().st_size < 128 * 1024
    manifest_raw = manifest_file.read_bytes()
    assert hashlib.sha256(manifest_raw).hexdigest() == MANIFEST_SHA256
    manifest = json.loads(manifest_raw)
    assert manifest["format"] == 1
    assert manifest["snapshot"] == "2026-08-26"
    assert manifest["entry_count"] == 180
    assert manifest["source_url"] == SOURCE_URL
    archive = manifest["source_archive"]
    assert archive == {
        "name": "ACcompactado.zip",
        "url": (
            "https://acraiz.icpbrasil.gov.br/credenciadas/"
            "CertificadosAC-ICP-Brasil/ACcompactado.zip"
        ),
        "bytes": 351321,
        "sha256": ARCHIVE_SHA256,
        "sha512": ARCHIVE_SHA512,
    }
    records = manifest["certificates"]
    assert len(records) == 180
    assert len({record["file"] for record in records}) == 180
    assert len({record["archive_name"] for record in records}) == 180
    expected_files = {Path(record["file"]) for record in records}
    expected_files |= {Path("NOTICE"), Path("manifest.json"), Path("SHA256SUMS")}
    assert {
        path.relative_to(share) for path in share.rglob("*") if path.is_file()
    } == expected_files
    assert all(not path.is_symlink() for path in args.package.rglob("*"))
    expected_directories = {
        Path("share"),
        Path("share/icp-brasil-ca-data"),
        Path("share/icp-brasil-ca-data/certificates"),
        Path("share/icp-brasil-ca-data/reference-ed521"),
    }
    assert {
        path.relative_to(args.package)
        for path in args.package.rglob("*")
        if path.is_dir()
    } == expected_directories
    assert all(
        path.relative_to(args.package).parts[0] == "share"
        for path in args.package.rglob("*")
    ), "data-only output must contain no activation, programs or trust directories"
    notice_raw = (share / "NOTICE").read_bytes()
    assert hashlib.sha256(notice_raw).hexdigest() == NOTICE_SHA256
    notice = notice_raw.decode("ascii")
    assert "ITI" in notice and "Attribution-NoDerivs 3.0" in notice
    assert "not a trust store" in notice
    assert "revocation" in notice and "reference-ed521" in notice
    sums = [record["sha256"] + "  " + record["file"] for record in records] + [
        MANIFEST_SHA256 + "  manifest.json",
        NOTICE_SHA256 + "  NOTICE",
    ]
    assert (share / "SHA256SUMS").read_text(encoding="ascii") == "\n".join(sums) + "\n"
    originals: dict[str, bytes] = {}
    algorithms: Counter[str] = Counter()
    for record in records:
        name = record["archive_name"]
        assert re.fullmatch(r"[A-Za-z0-9_-]+\.crt", name)
        reference = record["reference_only"]
        assert isinstance(reference, bool)
        directory = "reference-ed521" if reference else "certificates"
        assert record["file"] == directory + "/" + name
        assert reference == (name == "ICP-Brasilv7.crt")
        file = share / record["file"]
        raw = file.read_bytes()
        assert len(raw) == record["bytes"] and 1024 <= len(raw) <= 4096
        assert hashlib.sha256(raw).hexdigest() == record["sha256"], name
        assert raw.count(b"-----BEGIN CERTIFICATE-----") == 1
        assert raw.count(b"-----END CERTIFICATE-----") == 1
        assert b"PRIVATE KEY" not in raw
        der = ssl.PEM_cert_to_DER_cert(raw.decode("ascii"))
        assert hashlib.sha256(der).hexdigest() == record["der_sha256"], name
        details = native(args.openssl, "x509", "-in", str(file), "-noout", "-text")
        assert details.returncode == 0, details.stderr
        assert "CA:TRUE" in details.stdout and "Certificate Sign" in details.stdout
        algorithm = record["public_key_algorithm"]
        match = re.search(r"Public Key Algorithm: ([^\r\n]+)", details.stdout)
        assert match and match.group(1).strip() == algorithm
        assert reference == (algorithm == ED521)
        algorithms[algorithm] += 1
        originals[name] = raw
        if reference:
            refusal = native(
                args.openssl,
                "verify",
                "-check_ss_sig",
                "-no-CApath",
                "-no-CAstore",
                "-CAfile",
                str(file),
                str(file),
            )
            assert refusal.returncode != 0 and "decode error" in refusal.stderr
        print(
            f"PASS original CA data: {name}, exact bytes/DER, constraints, {algorithm}"
        )
    assert algorithms == Counter({"rsaEncryption": 175, "ED448": 4, ED521: 1})
    assert sum(b"\r\n" in raw for raw in originals.values()) == 27
    assert {name for name, raw in originals.items() if not raw.endswith(b"\n")} == {
        "AC_DIGITALSIGN_G3.crt"
    }
    assert sum(len(raw) for raw in originals.values()) == 451012
    assert {path.name for path in (share / "reference-ed521").iterdir()} == {
        "ICP-Brasilv7.crt"
    }
    if args.source_archive is not None:
        check_archive(args.source_archive, originals)
    print(
        "PASS opt-in data only: no global trust, CA bundle, signing client, "
        "current validity, chain verification or revocation claims"
    )


if __name__ == "__main__":
    main()
