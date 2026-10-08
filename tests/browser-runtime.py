#!/usr/bin/env python3
"""Render local fixtures with an installed browser and its normal sandbox."""

import argparse
import http.server
import os
import re
import shutil
import subprocess
import tempfile
import threading
from pathlib import Path

PAGE = b"""<!doctype html><html><head><title>Browser fixture</title></head>
<body><h1>Browser fixture</h1><output id="result">pending</output>
<canvas id="canvas" width="32" height="32"></canvas><script>
const canvas = document.getElementById('canvas');
const context = canvas.getContext('2d');
context.fillStyle = '#123456'; context.fillRect(0, 0, 32, 32);
const pixel = Array.from(context.getImageData(4, 4, 1, 1).data).join(',');
const arithmetic = Math.sqrt(1764) === 42 && 123456789n * 9n === 1111111101n;
const result = document.getElementById('result');
result.dataset.result = arithmetic && pixel === '18,52,86,255' ? 'pass' : 'fail';
result.textContent = 'JavaScript arithmetic and canvas: ' + result.dataset.result;
</script></body></html>"""


class Handler(http.server.BaseHTTPRequestHandler):
    requests = 0

    def do_GET(self):
        type(self).requests += 1
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(PAGE)))
        self.end_headers()
        self.wfile.write(PAGE)

    def log_message(self, format: str, *args: object) -> None:
        pass


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("browser", type=Path)
    parser.add_argument("version")
    parser.add_argument("state", type=Path)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="browser-", dir=args.state) as private:
        state = Path(private)
        environment = os.environ.copy()
        for variable, directory in (
            ("XDG_CONFIG_HOME", "config"),
            ("XDG_CACHE_HOME", "cache"),
            ("XDG_DATA_HOME", "data"),
            ("XDG_RUNTIME_DIR", "runtime"),
            ("TMPDIR", "tmp"),
        ):
            path = state / directory
            path.mkdir(mode=0o700)
            environment[variable] = str(path)

        def run(label, *options):
            result = subprocess.run(
                [str(args.browser), *options],
                env=environment,
                capture_output=True,
                timeout=45,
                check=False,
            )
            print(f"{label}: exit {result.returncode}")
            print(result.stdout.decode(errors="replace"))
            print(result.stderr.decode(errors="replace"))
            result.check_returncode()
            return result.stdout.decode(errors="replace")

        assert args.version in run("version", "--version")
        driver = args.browser.parent / "chromedriver"
        if driver.exists():
            result = subprocess.run(
                [str(driver), "--version"],
                env=environment,
                capture_output=True,
                timeout=15,
                check=True,
            )
            print(result.stdout.decode(errors="replace"))
            assert args.version in result.stdout.decode(errors="replace")
        options = (
            "--headless",
            "--disable-gpu",
            "--no-first-run",
            "--no-default-browser-check",
            "--disable-background-networking",
            "--disable-component-update",
            "--disable-sync",
            "--no-proxy-server",
            f"--user-data-dir={state / 'profile'}",
        )
        with http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler) as server:
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                url = f"http://127.0.0.1:{server.server_port}/"
                dom = run("localhost DOM", *options, "--dump-dom", url)
                assert 'data-result="pass"' in dom
                assert "JavaScript arithmetic and canvas: pass" in dom
                image = state / "render.png"
                run("localhost screenshot", *options, f"--screenshot={image}", url)
                assert image.read_bytes().startswith(b"\x89PNG\r\n\x1a\n")
                assert image.stat().st_size > 1000
                shutil.copyfile(image, args.state / f"{args.browser.name}.png")
                assert Handler.requests >= 2
                sandbox = run(
                    "sandbox status",
                    *options,
                    "--allow-chrome-scheme-url",
                    "--dump-dom",
                    "chrome://sandbox",
                )
                status_text = " ".join(re.sub(r"<[^>]+>", " ", sandbox).split())
                for status in (
                    "Layer 1 Sandbox Namespace",
                    "PID namespaces Yes",
                    "Network namespaces Yes",
                    "Seccomp-BPF sandbox Yes",
                ):
                    assert status in status_text, status
            finally:
                server.shutdown()
                thread.join(timeout=5)
        print(
            "PASS: local JavaScript, arithmetic, canvas, PNG and namespace/seccomp sandbox"
        )


if __name__ == "__main__":
    main()
