"""Verify the original PHIVE library closure and selected offline upstream tests."""

from __future__ import annotations

import argparse
import csv
import hashlib
import os
import re
import subprocess
import tarfile
import tempfile
import zipfile
from pathlib import Path

RUNTIME_MANIFEST = "50d40483a1537617ef68a4dc104b56dbd5221dd28b0f82c82df8b478c748a5ce"
TEST_MANIFEST = "707438df5b23f693c03b5f72f180702f022a8f7aced1b3900ecccb986f7e7375"
SUPPLEMENT_MANIFEST = "8bf2fe7e0e322a42d924625c53ffd600b19be753ca428cbe99b03bb00b638f1f"
UPSTREAM_SOURCE = "4d4b634fc03ed953041f3dbc872302aef54a5cdcf70060b7884d72dd3f5c1932"
TESTS = [
    [
        "phive-ves-repo",
        "com.helger.phive.ves.repo.RepoVESTopTocServiceCSVTest",
        "phive-ves-repo/src/test/java/com/helger/phive/ves/repo/RepoVESTopTocServiceCSVTest.java",
        "db5207f13c0aba2c54f26c187c1195d422e6825d33f0fde871c3e3dec7043041",
        1,
    ],
    [
        "phive-result-html",
        "com.helger.phive.result.html.PhiveHtmlHelperTest",
        "phive-result-html/src/test/java/com/helger/phive/result/html/PhiveHtmlHelperTest.java",
        "44b7fbda547b46aefa35b8a0fa83ac728a732da60f3588fc17d11c96fa49fe21",
        17,
    ],
    [
        "phive-result",
        "com.helger.phive.result.json.PhiveJsonHelperTest",
        "phive-result/src/test/java/com/helger/phive/result/json/PhiveJsonHelperTest.java",
        "a6719987cba54336d5c040db28714b526d7c07df8ab136e532f15ed8cc21c0b0",
        7,
    ],
    [
        "phive-result",
        "com.helger.phive.result.xml.PhiveXMLHelperTest",
        "phive-result/src/test/java/com/helger/phive/result/xml/PhiveXMLHelperTest.java",
        "36fa953702f88bac26a93615fca9153d0cc9b9be3551176ed0521b4b81df31f2",
        7,
    ],
    [
        "phive-ves-engine",
        "com.helger.phive.ves.engine.load.VESLoaderTest",
        "phive-ves-engine/src/test/java/com/helger/phive/ves/engine/load/VESLoaderTest.java",
        "85263e1735f7bd175b898c9fc56ba240e05e665accca6f84424bf39771eadcba",
        16,
    ],
    [
        "phive-ves-model",
        "com.helger.phive.ves.model.v1.VES1MarshallerTest",
        "phive-ves-model/src/test/java/com/helger/phive/ves/model/v1/VES1MarshallerTest.java",
        "ad8d6bc140d5e19a2cb43df18b50f65dcbf3554a902f8ed1c283c9218bd5159d",
        1,
    ],
    [
        "phive-xml-source",
        "com.helger.phive.xml.source.ValidationSourceXMLTest",
        "phive-xml-source/src/test/java/com/helger/phive/xml/source/ValidationSourceXMLTest.java",
        "5f797035222c9c6a2308bbea72e148143ce96bcd819c99487d854307ae01adca",
        9,
    ],
    [
        "phive-xml",
        "com.helger.phive.xml.ValidationExecutionManagerFuncTest",
        "phive-xml/src/test/java/com/helger/phive/xml/ValidationExecutionManagerFuncTest.java",
        "07f80c6d9f0b54648aa7337eb4a6063e969112bd180ff673021f40797fd90ede",
        1,
    ],
    [
        "phive-xml",
        "com.helger.phive.xml.schematron.ValidationExecutorSchematronPartialSourceFuncTest",
        "phive-xml/src/test/java/com/helger/phive/xml/schematron/ValidationExecutorSchematronPartialSourceFuncTest.java",
        "82d7b502472262adf97ec20a35b33c6a562f6929f073c3c833ac7273be472137",
        4,
    ],
]
REPO_HELPER = (
    "phive-ves-repo/src/test/java/com/helger/phive/ves/repo/MockRepoStorageLocalFileSystem.java",
    "d78e01ed20fdf8c11d7146c33a0c01a1c6d7c74711bd05fac9c26c51436fc4e7",
)
VES_EXAMPLES = [
    "ves-edifact-desadv-d01b.xml",
    "ves-sch-en16931-ubl-creditnote-1.3.10.xml",
    "ves-sch-en16931-ubl-invoice-1.3.10.xml",
    "ves-sch-peppol-bis-billing-ubl-invoice-2023.05.xml",
    "ves-sch-xrechnung-ubl-invoice-2.3.1.xml",
    "ves-xsd-ubl-creditnote-2.1.xml",
    "ves-xsd-ubl-invoice-2.1.xml",
]
NOTICE = re.compile(r"LICENSE|NOTICE|COPYRIGHT|license|notice|copyright")


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify_output(prefix: Path, count: int, expected: str) -> list[Path]:
    share = prefix / "share/phive"
    manifest = share / "artifacts.tsv"
    assert digest(manifest) == expected, "artifact pins differ from verified release"
    with manifest.open(newline="") as stream:
        rows = list(csv.DictReader(stream, delimiter="\t"))
    assert len(rows) == count
    libraries = []
    for row in rows:
        jar = share / "lib" / row["jar"]
        pom = share / "maven" / row["pom"]
        source = share / "source" / row["source"]
        for path, key in (
            (jar, "jar_sha256"),
            (pom, "pom_sha256"),
            (source, "source_sha256"),
        ):
            assert digest(path) == row[key], f"original bytes changed: {path.name}"
        stem = row["artifact"] + "-" + row["version"]
        if row["classifier"]:
            stem += "-" + row["classifier"]
        for archive, label in ((jar, "binary"), (source, "source")):
            with zipfile.ZipFile(archive) as zipped:
                for name in zipped.namelist():
                    if NOTICE.search(Path(name).name) and not name.endswith("/"):
                        notice = share / "notices" / stem / label / name
                        assert notice.read_bytes() == zipped.read(name), name
        libraries.append(jar)
    assert set((share / "lib").glob("*.jar")) == set(libraries)
    classpath = (share / "classpath").read_text().strip().split(":")
    assert classpath == [str(jar) for jar in libraries]
    assert not (prefix / "bin").exists(), "PHIVE is a library, not an invented CLI"
    print(f"PASS: {count} original JAR/POM/source artifacts and notices")
    return libraries


def verify_supplements(prefix: Path) -> None:
    share = prefix / "share/phive"
    assert digest(share / "supplements.tsv") == SUPPLEMENT_MANIFEST
    with (share / "supplements.tsv").open(newline="") as stream:
        rows = list(csv.DictReader(stream, delimiter="\t"))
    assert len(rows) == 7
    for row in rows:
        assert row["url"].startswith("https://")
        assert digest(share / "source/supplements" / row["file"]) == row["sha256"]
    assert (
        digest(share / "source/supplements/phive-12.2.0-source.tar.gz")
        == UPSTREAM_SOURCE
    )
    notices = {
        digest(path) for path in (share / "notices").rglob("*") if path.is_file()
    }
    for expected in (
        "9a3ac27f4c5954a3e4afcf8311e36be7cd84c32a3681312de7563ce112b9cad0",
        "7419ec28b8b41fffc3d26ec710e1416beeff91b1c2a14abb8e472db10082da46",
        "183a25ac443925952e3512a0eed785520f29359605a16a425633f48b768207ba",
        "74a1f0e7dcb8d2d4a619180c331e1ed5692850cc278866fc21f460e1252f2f42",
        "7839a9d2e2904e7dcb96b2db67e2177e1f69ee44d9e586b346b8d90b2cba8332",
        "cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30",
        "59cca96c0f6a6a9b674787a1e96d01ef29782a3b245f2e5d7c0fa05d8e9e6ce7",
    ):
        assert expected in notices, f"missing exact original legal notice: {expected}"
    print("PASS: seven exact full-source/legal supplements and original license texts")


def command(argv: list[str], cwd: Path, env: dict[str, str]) -> str:
    print("RUN:", " ".join(argv), flush=True)
    result = subprocess.run(
        argv, cwd=cwd, env=env, text=True, capture_output=True, timeout=180, check=False
    )
    print(result.stdout, end="", flush=True)
    print(result.stderr, end="", flush=True)
    assert result.returncode == 0, f"command failed: exit {result.returncode}"
    return result.stdout


def run_upstream(
    prefix: Path, libraries: list[Path], tests: list[Path], javac: Path, probe: Path
) -> None:
    assert os.getuid() != 0, "functional tests require an unprivileged account"
    assert {path.name for path in Path("/sys/class/net").iterdir()} == {"lo"}, (
        "functional tests require a private offline network namespace"
    )
    with tempfile.TemporaryDirectory(prefix="phive-offline-") as temporary:
        work = Path(temporary)
        home = work / "home"
        home.mkdir(mode=0o700)
        env = {
            "HOME": str(home),
            "TMPDIR": str(work),
            "PATH": str(javac.parent),
            "LANG": "C.UTF-8",
            "LC_ALL": "C.UTF-8",
            "TZ": "UTC",
        }
        archive = prefix / "share/phive/source/supplements/phive-12.2.0-source.tar.gz"
        with tarfile.open(archive) as source:
            source.extractall(work, filter="data")
        root = work / "phive-6df39cb01e7fb11a2353c424c7ef50561ea3c513"
        assert sorted(
            path.name
            for path in (root / "phive-ves-model/src/test/resources/ves/v1").glob(
                "*.xml"
            )
        ) == sorted(VES_EXAMPLES)
        classes = work / "classes"
        classes.mkdir()
        cp = ":".join(str(jar) for jar in libraries + tests)
        sources = []
        for _, _, relative, pin, _ in TESTS:
            path = root / relative
            assert digest(path) == pin, f"upstream test changed: {relative}"
            sources.append(str(path))
        helper = root / REPO_HELPER[0]
        assert digest(helper) == REPO_HELPER[1], "upstream repository helper changed"
        sources.append(str(helper))
        sources.append(str(probe))
        command(
            [
                str(javac),
                "-J-Xmx256m",
                "-J-XX:+UseSerialGC",
                "--release",
                "17",
                "-cp",
                cp,
                "-d",
                str(classes),
                *sources,
            ],
            work,
            env,
        )
        java = (prefix / "share/phive/java").read_text().strip()
        assert java.startswith("/gnu/store/") and java.endswith("/bin/java")
        flags = [
            "-Xmx384m",
            "-Xss512k",
            "-XX:+UseSerialGC",
            "-XX:ActiveProcessorCount=2",
            "-Djava.awt.headless=true",
            "-Djava.io.tmpdir=" + str(work),
            "-Djavax.xml.accessExternalDTD=",
            "-Djavax.xml.accessExternalSchema=",
            "-Djavax.xml.accessExternalStylesheet=",
        ]
        command(
            [
                java,
                *flags,
                "-cp",
                ":".join([cp, str(classes)]),
                "PhiveOfflineProbe",
                str(prefix),
            ],
            work,
            env,
        )
        total = 0
        for module, name, _, _, count in TESTS:
            directory = root / module
            (directory / "target").mkdir(exist_ok=True)
            resources = directory / "src/test/resources"
            # HTML constructs its inputs and reads installed CSS.  The CSV
            # repository test creates target/test-repo in this private cwd.
            # Neither class has upstream test resources; XML/VES classes do.
            assert resources.is_dir() or module in {
                "phive-result-html",
                "phive-ves-repo",
            }
            resource_paths = [str(resources)] if resources.is_dir() else []
            output = command(
                [
                    java,
                    *flags,
                    "-cp",
                    ":".join([cp, str(classes), *resource_paths]),
                    "org.junit.runner.JUnitCore",
                    str(name),
                ],
                directory,
                env,
            )
            assert f"OK ({count} test" in output, f"wrong JUnit case count for {name}"
            total += int(count)
        assert total == 63
        print("PASS: 63 unchanged upstream JUnit cases, seven nonempty VES examples")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("prefix", type=Path)
    parser.add_argument("--tests", type=Path)
    parser.add_argument("--runtime", action="store_true")
    parser.add_argument("--javac", type=Path)
    parser.add_argument("--probe", type=Path)
    args = parser.parse_args()
    libraries = verify_output(args.prefix, 50, RUNTIME_MANIFEST)
    verify_supplements(args.prefix)
    if args.tests is not None:
        tests = verify_output(args.tests, 5, TEST_MANIFEST)
    else:
        tests = []
    if args.runtime:
        assert (
            args.tests is not None and args.javac is not None and args.probe is not None
        )
        run_upstream(args.prefix, libraries, tests, args.javac, args.probe)


if __name__ == "__main__":
    main()
