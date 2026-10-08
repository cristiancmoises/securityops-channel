"""Check an installed Arelle output inside a network-isolated Guix container."""

import json
import platform
import ssl
import subprocess
import sys
import tempfile
import tkinter
from importlib.metadata import version
from pathlib import Path

import arelle
import lxml.etree as lxml_etree
from arelle import Cntlr, TkTableWrapper
from arelle.logging.handlers.LogToBufferHandler import LogToBufferHandler
from arelle.ModelFormulaObject import FormulaOptions


def main():
    output = Path(sys.argv[1]).resolve()
    fixtures = Path(sys.argv[2]).resolve()
    library = Path(arelle.__file__).resolve().parent
    assert library.is_relative_to(output), library
    wrapper = (output / "bin" / "arelleCmdLine").read_text()
    assert "python-pytest" not in wrapper, "build-only pytest leaked into runtime"
    assert "python-setuptools" not in wrapper, (
        "build-only setuptools leaked into runtime"
    )
    assert "-tk/lib/python" in wrapper, "Python Tk output missing from runtime"
    assert version("arelle-release") == "2.46.0"
    assert version("filelock") == "4.0.12"
    assert version("lxml") == "6.1.3"
    assert version("pillow") == "12.3.0"
    print("Loaded lxml extension:", Path(lxml_etree.__file__).resolve())
    assert "-python-lxml-6.1.3/" in str(Path(lxml_etree.__file__).resolve())
    print(
        "lxml parser versions:",
        "runtime",
        lxml_etree.LIBXML_VERSION,
        "compiled",
        lxml_etree.LIBXML_COMPILED_VERSION,
        "libxslt",
        lxml_etree.LIBXSLT_VERSION,
    )
    assert lxml_etree.LIBXML_VERSION == lxml_etree.LIBXML_COMPILED_VERSION
    assert lxml_etree.LIBXML_VERSION == (2, 15, 4)
    assert lxml_etree.LIBXSLT_VERSION == (1, 1, 45)
    print("TLS runtime:", ssl.OPENSSL_VERSION)
    assert ssl.OPENSSL_VERSION.startswith("OpenSSL 3.5.9 ")
    assert (library / "plugin" / "inlineXbrlDocumentSet.py").is_file()
    assert (
        library / "resources" / "libs" / "TkTable" / "linux-x86_64" / "license.txt"
    ).is_file()
    assert (
        library
        / "resources"
        / "cache"
        / "http"
        / "www.xbrl.org"
        / "2003"
        / "xbrl-instance-2003-12-31.xsd"
    ).is_file()

    with tempfile.TemporaryDirectory(prefix="arelle-check-") as scratch:
        scratch = Path(scratch)
        for name in ("valid", "invalid", "remote"):
            log = scratch / f"{name}.json"
            command = [
                str(output / "bin" / "arelle"),
                "--file",
                str(fixtures / f"{name}.xbrl"),
                "--validate",
                "--internetConnectivity=offline",
                "--disablePersistentConfig",
                "--plugins=inlineXbrlDocumentSet",
                "--logFile",
                str(log),
            ]
            result = subprocess.run(
                command, check=True, text=True, capture_output=True, timeout=60
            )
            print(result.stdout, end="")
            print(result.stderr, end="", file=sys.stderr)
            entries = json.loads(log.read_text())["log"]
            errors = [
                entry for entry in entries if entry["level"] in ("error", "critical")
            ]
            print(name, json.dumps(entries))
            if name == "valid":
                assert not errors, errors
            elif name == "invalid":
                assert any(
                    entry["code"] == "xbrl.4.6.1:itemContextRef" for entry in errors
                ), errors
            else:
                assert any(
                    entry["code"] == "IOerror"
                    and "Disable offline mode to attempt download"
                    in entry["message"]["text"]
                    and "https://example.invalid/unavailable-taxonomy.xsd"
                    in entry["message"]["text"]
                    for entry in errors
                ), errors

        controller = Cntlr.Cntlr(
            logFileName="logToBuffer", disable_persistent_config=True
        )
        controller.webCache.workOffline = True
        controller.modelManager.formulaOptions = FormulaOptions()
        model = controller.modelManager.load(str(fixtures / "valid.xbrl"))
        controller.modelManager.validate()
        assert isinstance(controller.logHandler, LogToBufferHandler)
        print("Library validation log:", controller.logHandler.getText())
        assert not model.errors, model.errors
        assert len(model.facts) == 1, model.facts
        assert model.facts[0].qname.localName == "Revenue"
        assert model.facts[0].xValue == 42
        controller.modelManager.close()
        controller.close()
    root = tkinter.Tk()
    try:
        values = TkTableWrapper.ArrayVar(root)
        table = TkTableWrapper.Table(root, rows=2, cols=2, variable=values)
        table.pack()
        table.set(**{"0,0": "offline"})
        root.update()
        assert table.get("0,0") == "offline"
        assert root.tk.call("package", "require", "Tktable") == "2.12.1"
        assert TkTableWrapper._TKTABLE_LOADED
        print("TkTable native GUI loading:", platform.machine(), "2.12.1")
    finally:
        root.destroy()
    print(
        "Arelle installed CLI, library, plugins, taxonomy cache and offline validation passed"
    )


if __name__ == "__main__":
    main()
