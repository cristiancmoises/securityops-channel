"""The optional browser view must use the same exact, sanitized farm facts."""

import importlib.util
import json
import shutil
import subprocess
import tempfile
import threading
import unittest
from datetime import datetime, timezone
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "etc/build-farm/site/explore.py"
SPEC = importlib.util.spec_from_file_location("farm_explore", MODULE)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("farm explorer module is unavailable")
explore = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(explore)

PATH_A = "/gnu/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-example-1.0"
PATH_B = "/gnu/store/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-example-2.0"
PATH_ROOT = "/gnu/store/cccccccccccccccccccccccccccccccc-home-root"
NOW = datetime(2026, 10, 14, 22, 0, tzinfo=timezone.utc)


def target(path, memberships):
    return {"path": path, "memberships": memberships}


def member(source, *, kind="package", direct=False, name="example", version="1.0"):
    return {
        "source": source,
        "kind": kind,
        "direct": direct,
        "name": name,
        "version": version,
        "output": "out",
        "drv": PATH_A + ".drv",
        "job": "",
    }


class FarmExploreTests(unittest.TestCase):
    def test_payload_uses_exact_output_identity_and_source_memberships(self):
        targets = [
            target(
                PATH_A, [member("channel", direct=True), member("home", direct=True)]
            ),
            target(PATH_B, [member("home", name="example", version="2.0")]),
            target(PATH_ROOT, [member("home", kind="output", name="home-root")]),
        ]
        payload = explore.build_payload(
            "home",
            targets,
            {PATH_A},
            {PATH_A, PATH_B},
            {},
            NOW,
            active_channel_paths=set(),
        )
        self.assertEqual(payload["schema"], 1)
        self.assertEqual(payload["source"], "home")
        self.assertEqual(payload["total"], 2)
        self.assertEqual(payload["other_outputs"], 1)
        self.assertEqual([item["path"] for item in payload["nodes"]], [PATH_A, PATH_B])
        self.assertEqual(payload["nodes"][0]["sources"], ["channel", "home"])
        self.assertEqual(payload["nodes"][0]["status"], "available")
        self.assertEqual(payload["nodes"][1]["status"], "stored")
        self.assertEqual(payload["nodes"][0]["id"], 1)

    def test_active_channel_status_and_no_false_yellow(self):
        targets = [target(PATH_A, [member("channel", direct=True)])]
        active = explore.build_payload(
            "channel",
            targets,
            set(),
            set(),
            {},
            NOW,
            active_channel_paths={PATH_A},
        )
        idle = explore.build_payload(
            "channel",
            targets,
            set(),
            set(),
            {},
            NOW,
            active_channel_paths=set(),
        )
        self.assertEqual(active["nodes"][0]["status"], "building")
        self.assertEqual(idle["nodes"][0]["status"], "unavailable")

    def test_shared_active_output_has_same_status_in_every_source(self):
        targets = [target(PATH_A, [member("channel"), member("home")])]
        for source in ("channel", "home"):
            with self.subTest(source=source):
                payload = explore.build_payload(
                    source,
                    targets,
                    set(),
                    set(),
                    {},
                    NOW,
                    active_channel_paths={PATH_A},
                )
                self.assertEqual(payload["nodes"][0]["status"], "building")

    def test_stale_source_is_explicit_in_public_map_data(self):
        targets = [target(PATH_A, [member("home")])]
        payload = explore.build_payload(
            "home",
            targets,
            set(),
            set(),
            {},
            NOW,
            active_channel_paths=set(),
            inventory_stale=True,
        )
        self.assertIs(payload["inventory_stale"], True)
        self.assertIn('id="inventory-warning"', explore.render_page("en"))

    def test_rejects_unknown_source_and_untrusted_text(self):
        with self.assertRaises(ValueError):
            explore.build_payload(
                "extras", [], set(), set(), {}, NOW, active_channel_paths=set()
            )
        with self.assertRaises(ValueError):
            explore.build_payload(
                "home",
                [target(PATH_A, [member("home", name="<script>")])],
                set(),
                set(),
                {},
                NOW,
                active_channel_paths=set(),
            )

    def test_english_and_portuguese_pages_are_opt_in(self):
        english = explore.render_page("en")
        portuguese = explore.render_page("pt-br")
        self.assertIn('src="/explore/app.js"', english)
        self.assertIn('<link rel="icon" href="data:,">', english)
        self.assertIn('href="/"', english)
        self.assertIn('href="/pt-br/"', portuguese)
        self.assertIn("Membership map", english)
        self.assertIn("Mapa de pertencimento", portuguese)
        self.assertIn("This is not a dependency graph", english)
        self.assertIn('role="img" aria-label="Package membership map"', english)
        self.assertIn('id="selected" aria-live="polite"', english)
        self.assertIn("não é um grafo de dependências", portuguese)
        self.assertNotIn("<script>", english)

    def test_assets_are_complete_and_json_is_utf8(self):
        targets = [target(PATH_A, [member("channel", direct=True)])]
        files = explore.build_assets(targets, {PATH_A}, {PATH_A}, {}, NOW, set())
        self.assertEqual(
            set(files),
            {
                "explore/index.html",
                "pt-br/explore/index.html",
                "explore/data.json",
                "explore/app.js",
            },
        )
        data = json.loads(files["explore/data.json"])
        self.assertEqual(set(data["sources"]), {"channel", "system", "home"})
        self.assertEqual(data["sources"]["channel"]["nodes"][0]["path"], PATH_A)
        self.assertEqual(data["sources"]["home"]["source_at"], "2026-10-14T22:00:00Z")
        self.assertIn(b"fetch(", files["explore/app.js"])
        self.assertIn(b'fetch("/explore/data.json"', files["explore/app.js"])
        self.assertNotIn(b'tabindex: "0"', files["explore/app.js"])
        self.assertNotIn(b"signed public narinfo", files["explore/app.js"])

    def test_pending_inventory_is_not_a_zero_package_source_in_chromium(self):
        chromium = shutil.which("chromium")
        if chromium is None:
            self.skipTest("Chromium is not available")
        targets = [target(PATH_A, [member("channel", direct=True)])]
        assets = explore.build_assets(
            targets,
            {PATH_A},
            {PATH_A},
            {},
            NOW,
            set(),
            pending_sources={"system", "home"},
        )
        data = json.loads(assets["explore/data.json"])
        self.assertTrue(data["sources"]["home"]["inventory_pending"])
        assets["explore/index.html"] = assets["explore/index.html"].replace(
            b"</body>", b'<script src="/explore/probe.js" defer></script></body>'
        )
        assets["explore/probe.js"] = (
            b"setTimeout(()=>{const source=document.getElementById('source');"
            b"source.value='home';source.dispatchEvent(new Event('change'));"
            b"document.body.dataset.pending=document.getElementById('count').textContent;"
            b"document.body.dataset.empty=String(document.getElementById('count').textContent.includes('0 shown'));"
            b"},500);"
        )
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for relative, content in assets.items():
                path = root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(content)
            (root / "style.css").write_bytes(MODULE.with_name("style.css").read_bytes())
            handler = partial(SimpleHTTPRequestHandler, directory=str(root))
            server = ThreadingHTTPServer(("127.0.0.1", 0), handler)
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                result = subprocess.run(
                    [
                        chromium,
                        "--headless",
                        "--no-sandbox",
                        "--disable-gpu",
                        "--disable-dev-shm-usage",
                        f"--user-data-dir={root / 'profile-pending'}",
                        "--virtual-time-budget=2000",
                        "--window-size=320,800",
                        "--dump-dom",
                        f"http://127.0.0.1:{server.server_port}/explore/",
                    ],
                    capture_output=True,
                    text=True,
                    timeout=30,
                    check=True,
                )
                self.assertIn('data-pending="Inventory in preparation"', result.stdout)
                self.assertIn('data-empty="false"', result.stdout)
            finally:
                server.shutdown()
                server.server_close()
                thread.join(timeout=5)

    def test_chromium_loads_the_optional_map_without_a_live_api(self):
        chromium = shutil.which("chromium")
        if chromium is None:
            self.skipTest("Chromium is not available")
        targets = [target(PATH_A, [member("channel", direct=True), member("home")])]
        assets = explore.build_assets(targets, {PATH_A}, {PATH_A}, {}, NOW, set())
        assets["explore/index.html"] = assets["explore/index.html"].replace(
            b'<script src="/explore/app.js" defer></script>',
            b"<script>window.__farmClock=Date.parse('2026-10-15T21:00:00Z');"
            b"Date.now=()=>window.__farmClock;"
            b"window.setInterval=(fn)=>{window.__farmTick=fn;return 1;};</script>"
            b'<script src="/explore/app.js" defer></script>',
        )
        assets["explore/index.html"] = assets["explore/index.html"].replace(
            b"</body>", b'<script src="/explore/probe.js" defer></script></body>'
        )
        assets["explore/probe.js"] = (
            b"document.body.dataset.background=getComputedStyle(document.body).backgroundColor;"
            b"document.body.dataset.overflow=String(document.documentElement.scrollWidth>"
            b"document.documentElement.clientWidth);"
            b"document.body.dataset.viewport=String(document.documentElement.clientWidth);"
            b"setTimeout(()=>{const warning=document.getElementById('inventory-warning');"
            b"document.body.dataset.initialFresh=String(warning.hidden);"
            b"window.__farmClock=Date.parse('2026-10-15T23:00:00Z');"
            b"window.__farmTick();document.body.dataset.rolloverStale=String(!warning.hidden);"
            b"const control=document.getElementById('source');"
            b"control.value='home';control.dispatchEvent(new Event('change'));},500);"
        )
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for relative, content in assets.items():
                path = root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(content)
            (root / "style.css").write_bytes(MODULE.with_name("style.css").read_bytes())
            handler = partial(SimpleHTTPRequestHandler, directory=str(root))
            server = ThreadingHTTPServer(("127.0.0.1", 0), handler)
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                for width in (320, 768, 1024, 1440):
                    with self.subTest(width=width):
                        result = subprocess.run(
                            [
                                chromium,
                                "--headless",
                                "--no-sandbox",
                                "--disable-gpu",
                                "--disable-dev-shm-usage",
                                f"--user-data-dir={root / f'profile-{width}'}",
                                "--virtual-time-budget=2000",
                                f"--window-size={width},800",
                                "--dump-dom",
                                f"http://127.0.0.1:{server.server_port}/explore/",
                            ],
                            capture_output=True,
                            text=True,
                            timeout=30,
                            check=True,
                        )
                        self.assertIn('data-background="rgb(0, 0, 0)"', result.stdout)
                        self.assertIn('data-overflow="false"', result.stdout)
                        self.assertIn('data-initial-fresh="true"', result.stdout)
                        self.assertIn('data-rollover-stale="true"', result.stdout)
                        self.assertIn("1 shown of 1 matching packages", result.stdout)
                        self.assertIn('class="map-node available"', result.stdout)
                        self.assertIn("example-1.0 · Public NAR route", result.stdout)
                        self.assertIn(
                            'class="map-hub-label">Home</text>', result.stdout
                        )
                        self.assertNotIn('class="map-point" tabindex=', result.stdout)
                        self.assertIn(
                            'id="inventory-warning" class="stale-warning" role="status">',
                            result.stdout,
                        )
            finally:
                server.shutdown()
                server.server_close()
                thread.join(timeout=5)


if __name__ == "__main__":
    unittest.main()
