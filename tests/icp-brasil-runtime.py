#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify the installed ICP-Brasil dataset without registering any trust."""

import argparse
import hashlib
import re
import ssl
import subprocess
import tempfile
from pathlib import Path

# Original-file digest and certificate DER fingerprint, independently obtained
# from the official registry. A different CA, even if valid, must fail.
ROOTS = {
    4: (
        "857ff3bf31628979e479c5bc0bdf3e706bcc7bafb7ddf0c1134fc21f1cfab141",
        "f0c15afd258fb674e7a96e1a50ff873149364b9ec70d4d93c7a9f1eb6060d020",
    ),
    5: (
        "5bd85f219695dabe6cf3d4bd713d9bd8e41b2323194022acf1acd658daef148a",
        "caa53fc6091c6951887c976e378f6ef89aa6377c55d97b6475422b71ed7e9b17",
    ),
    6: (
        "a91e45782e58755dffc6621cb05c2342db74398ffc6e930b0b3a23325a3bfdfd",
        "3bdb9b509352f1d3d71c2bf64d9a38a4e6cebda27809d77f7ac476cbde6e314a",
    ),
    7: (
        "4fe1d8599fc00f0b61b12391c98d97af36bcada115bd894f8755e01e212bc4be",
        "5657e70580eb678983f3ed7dfce091d84cae6549389a47fccda8d0e4dc2cf576",
    ),
    10: (
        "3b3ef39649ba13e10a99bc042cfc112723d8e0503326174f15ab89941a0f33e0",
        "6e0bff069a26994c15de2c4888cc54af84882e5495b7fbf66be9ccffec7489f6",
    ),
    11: (
        "1437394beb7eb04180a94c480319f432dc27ca9d6ebc036b73f10e2a17a7d7d8",
        "1406710058180fa4081aab3f246f1702429c552a11fa3143b84c88cb3ab8e5e7",
    ),
    12: (
        "ce6c66c73e41b12881ea8a9b8cb7efef9a482ea012c3cd3b843667e37a7a145c",
        "d8478e37ce19c690cf657381e68fe600e4e1a042536830f06847e03e554c4b01",
    ),
    13: (
        "da54711b5816a2487903c62de28402dca2eea21ccc4e977f1d2645486d84d30c",
        "2b07d0bc02c4a6e0478ed22d0d99e8f97e1827b269097696a7feb6aad30c3ac8",
    ),
}
BUNDLES = {
    "document-signing": (4, 5, 6, 12, 13),
    "tls": (10,),
    "code-signing": (11,),
}


def command(openssl, *arguments):
    return subprocess.run(
        [str(openssl), *map(str, arguments)],
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        timeout=15,
        check=False,
    )


def verify(openssl, file, *arguments):
    return command(
        openssl,
        "verify",
        "-check_ss_sig",
        "-no-CApath",
        "-no-CAstore",
        "-auth_level",
        "2",
        "-CAfile",
        file,
        *arguments,
        file,
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package", type=Path)
    parser.add_argument("openssl", type=Path)
    args = parser.parse_args()
    share = args.package / "share/icp-brasil"
    roots = share / "roots"
    assert roots.is_dir(), "installed root dataset is missing"
    expected_files = {f"ICP-Brasilv{version}.crt" for version in ROOTS if version != 7}
    assert {file.name for file in roots.glob("*.crt")} == expected_files
    reference = share / "reference-ed521"
    assert {file.name for file in reference.iterdir()} == {"ICP-Brasilv7.crt"}
    assert not (args.package / "etc").exists(), "automatic trust directory found"
    assert not (args.package / "bin").exists(), "unexpected activation program"
    notice = (roots / "NOTICE").read_text()
    assert "Attribution-NoDerivs 3.0" in notice and "ITI" in notice
    originals = {}
    with tempfile.TemporaryDirectory(prefix="icp-brasil-check-") as directory:
        state = Path(directory)
        state.chmod(0o700)
        for version, (file_digest, fingerprint) in ROOTS.items():
            file = (reference if version == 7 else roots) / f"ICP-Brasilv{version}.crt"
            data = file.read_bytes()
            assert hashlib.sha256(data).hexdigest() == file_digest, file
            assert data.count(b"-----BEGIN CERTIFICATE-----") == 1, file
            der = ssl.PEM_cert_to_DER_cert(data.decode("ascii"))
            assert hashlib.sha256(der).hexdigest() == fingerprint, file
            originals[version] = data
            metadata = command(
                args.openssl,
                "x509",
                "-in",
                file,
                "-noout",
                "-subject",
                "-issuer",
                "-ext",
                "basicConstraints,keyUsage",
            )
            assert metadata.returncode == 0, metadata.stderr
            assert f"Raiz Brasileira v{version}" in metadata.stdout
            assert "CA:TRUE" in metadata.stdout
            assert "Certificate Sign, CRL Sign" in metadata.stdout
            if version == 7:
                details = command(args.openssl, "x509", "-in", file, "-noout", "-text")
                assert (
                    details.returncode == 0
                    and "1.3.6.1.4.1.44588.2.1" in details.stdout
                )
                unsupported = verify(args.openssl, file)
                assert (
                    unsupported.returncode != 0 and "decode error" in unsupported.stderr
                )
                print(
                    "PASS v7: original bytes/fingerprint, Ed521 reference isolation; "
                    "native verification refused, not claimed"
                )
                continue
            verified = verify(args.openssl, file)
            assert verified.returncode == 0, verified.stderr
            assert verified.stdout.strip() == f"{file}: OK", verified.stdout
            # Use real OpenSSL verification failures, not generic exceptions.
            for time, error in ((0, "error 9"), (2524608000, "error 10")):
                invalid_time = verify(args.openssl, file, "-attime", time)
                assert invalid_time.returncode != 0 and error in invalid_time.stderr
            damaged = bytearray(der)
            damaged[-1] ^= 1
            tampered = state / f"tampered-v{version}.pem"
            tampered.write_text(ssl.DER_cert_to_PEM_cert(bytes(damaged)))
            rejected = verify(args.openssl, tampered)
            assert rejected.returncode != 0 and "error 7" in rejected.stderr
            assert "certificate signature failure" in rejected.stderr
            print(
                f"PASS v{version}: original bytes, identity, self-signature, "
                "validity and modified-signature refusal"
            )
    for name, versions in BUNDLES.items():
        bundle = share / f"{name}.pem"
        data = bundle.read_bytes()
        assert data == b"".join(originals[version] for version in versions), bundle
        certificates = re.findall(
            b"-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----", data, re.DOTALL
        )
        assert len(certificates) == len(versions), bundle
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
        context.load_verify_locations(cafile=str(bundle))
        assert context.cert_store_stats()["x509_ca"] == len(versions)
        print(f"PASS {name}: exact purpose selection and actual CA loader")
    print("PASS no global trust registration; no intermediate/revocation claims")


if __name__ == "__main__":
    main()
