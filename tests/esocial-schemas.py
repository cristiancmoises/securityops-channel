#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Check the installed, unmodified eSocial data in a Guix build sandbox."""

import pathlib
import resource
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
import zipfile


for kind, value in ((resource.RLIMIT_AS, 1073741824),
                    (resource.RLIMIT_NPROC, 128),
                    (resource.RLIMIT_FSIZE, 16777216),
                    (resource.RLIMIT_CPU, 120),
                    (resource.RLIMIT_CORE, 0)):
    resource.setrlimit(kind, (value, value))

dataset, installed, archive, xmllint = sys.argv[1:]
root = pathlib.Path(installed)
checks = 0


def check(condition, label):
    global checks
    if not condition:
        raise AssertionError(label)
    checks += 1
    print(f"ok {checks}: {label}", flush=True)


with zipfile.ZipFile(archive) as original:
    files = [entry for entry in original.infolist() if not entry.is_dir()]
    expected_files = {pathlib.PurePosixPath("source.zip"),
                      pathlib.PurePosixPath("ATTRIBUTION")}
    for entry in files:
        relative = pathlib.PurePosixPath(entry.filename)
        if dataset == "communication":
            relative = pathlib.PurePosixPath(*relative.parts[1:])
        expected_files.add(relative)
        check(not relative.is_absolute() and ".." not in relative.parts,
              f"archive path is local: {relative}")
        path = root / relative
        check(path.is_file() and path.read_bytes() == original.read(entry),
              f"installed bytes match official archive: {relative}")
    actual_files = {pathlib.PurePosixPath(path.relative_to(root))
                    for path in root.rglob("*") if path.is_file()}
    check(actual_files == expected_files,
          "only official data, original archive and attribution are installed")

schemas = sorted(root.rglob("*.xsd"))
expected_count = {"events": 52, "communication": 15}[dataset]
check(len(schemas) == expected_count, "complete schema set installed")
namespace = {"xs": "http://www.w3.org/2001/XMLSchema"}
for schema in schemas:
    document = ET.parse(schema)
    for node in document.findall("xs:include", namespace) + document.findall(
            "xs:import", namespace):
        location = node.get("schemaLocation")
        check(bool(location) and ":" not in location,
              f"explicit local import in {schema.name}")
        resolved = (schema.parent / location).resolve()
        check(resolved.is_relative_to(root.resolve()) and resolved.is_file(),
              f"import resolves inside installed data: {location}")

with tempfile.TemporaryDirectory(prefix="esocial-check-") as scratch:
    document = pathlib.Path(scratch) / "fixture.xml"

    def validate(schema, xml, expected, label):
        document.write_text(xml, encoding="utf-8")
        result = subprocess.run(
            [xmllint, "--nonet", "--noout", "--schema", str(schema), str(document)],
            capture_output=True, text=True, timeout=15,
            env={"HOME": scratch, "LC_ALL": "C", "XML_CATALOG_FILES": ""})
        if result.returncode != expected:
            print(f"{label}: expected exit {expected}, got {result.returncode}",
                  file=sys.stderr)
            print(result.stderr, file=sys.stderr)
        check(result.returncode == expected, label)

    # xmllint returns 3 for a document rejected by a compiled schema, versus 5
    # for a schema compilation error.  This exercises every installed import.
    for schema in schemas:
        validate(schema, "<absent-root/>", 3,
                 f"schema compiles offline: {schema.relative_to(root)}")

    if dataset == "events":
        event = '''<eSocial xmlns="http://www.esocial.gov.br/schema/evt/evtExclusao/v_S_01_03_00">
  <evtExclusao Id="ID1ABCDEF123456202610021200000000001">
    <ideEvento><tpAmb>2</tpAmb><procEmi>1</procEmi><verProc>fixture</verProc></ideEvento>
    <ideEmpregador><tpInsc>1</tpInsc><nrInsc>ABCDEF12345600</nrInsc></ideEmpregador>
    <infoExclusao><tpEvento>S-1000</tpEvento><nrRecEvt>1.2.0000000000000000001</nrRecEvt></infoExclusao>
  </evtExclusao>
  <Signature xmlns="http://www.w3.org/2000/09/xmldsig#">
    <SignedInfo>
      <CanonicalizationMethod Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"/>
      <SignatureMethod Algorithm="http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"/>
      <Reference URI="#ID1ABCDEF123456202610021200000000001">
        <DigestMethod Algorithm="http://www.w3.org/2001/04/xmlenc#sha256"/>
        <DigestValue>AA==</DigestValue>
      </Reference>
    </SignedInfo><SignatureValue>AA==</SignatureValue>
  </Signature>
</eSocial>'''
        # Dummy digest/signature bytes test XSD structure, not cryptography or
        # government acceptance.  No fixture is submitted to a live service.
        schema = root / "evtExclusao.xsd"
        validate(schema, event, 0, "S-3000 accepts alphanumeric CNPJ structure")
        validate(schema, event.replace("ABCDEF12345600", "00000000000000"), 0,
                 "S-3000 accepts numeric CNPJ structure")
        validate(schema, event.replace("<tpAmb>2", "<tpAmb>99"), 3,
                 "invalid environment rejected")
        validate(schema, event.replace("ABCDEF12345600", "invalid"), 3,
                 "invalid registration structure rejected")
        validate(schema, event.replace("<tpEvento>S-1000</tpEvento>", ""), 3,
                 "missing mandatory event type rejected")
        validate(schema, event.replace("v_S_01_03_00", "v_S_01_02_00"), 3,
                 "wrong layout namespace rejected")
        validate(schema, event[:-10], 4, "malformed event XML rejected")
    else:
        schema = root / "XSD/LoteEventos/Envio/EnvioLoteEventos-v1_1_1.xsd"
        envelope = '''<eSocial xmlns="http://www.esocial.gov.br/schema/lote/eventos/envio/v1_1_1">
  <envioLoteEventos grupo="1">
    <ideEmpregador><tpInsc>1</tpInsc><nrInsc>00000000</nrInsc></ideEmpregador>
    <ideTransmissor><tpInsc>1</tpInsc><nrInsc>00000000000000</nrInsc></ideTransmissor>
    <eventos><evento Id="fixture"><payload xmlns="urn:esocial-fixture"/></evento></eventos>
  </envioLoteEventos>
</eSocial>'''
        validate(schema, envelope, 0, "numeric communication envelope accepted")
        validate(schema, envelope.replace(' grupo="1"', ""), 3,
                 "missing envelope group rejected")
        validate(schema, envelope.replace(' Id="fixture"', ""), 3,
                 "missing nested event identifier rejected")
        validate(schema, envelope.replace("00000000</nrInsc>", "ABCDEF12</nrInsc>"), 3,
                 "communication v1.6 retains its numeric-only registration rule")
        example = root / "XSD/Eventos/RetornoEvento/exemplo.xml"
        result = subprocess.run(
            [xmllint, "--nonet", "--noout", "--schema",
             str(example.with_name("RetornoEvento-v1_3_0.xsd")), str(example)],
            capture_output=True, text=True, timeout=15,
            env={"HOME": scratch, "LC_ALL": "C", "XML_CATALOG_FILES": ""})
        if result.returncode:
            print(result.stderr, file=sys.stderr)
        check(result.returncode == 0, "official processing-response example accepted")

print(f"PASS: {checks} checks; {len(schemas)} installed schemas compiled offline")
