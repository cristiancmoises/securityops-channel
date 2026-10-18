"""Static System/Home catalog pages preserve every exact output."""

import importlib.util
import shutil
import subprocess
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "etc/build-farm/site/render.py"
CATALOG = ROOT / "etc/build-farm/site/catalog.py"
NOW = datetime(2026, 10, 14, 2, 30, tzinfo=timezone.utc)


def load(path, name):
    if not path.is_file():
        raise AssertionError(f"missing module: {path.name}")
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot import {path.name}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


catalog = load(CATALOG, "farm_catalog_render_test")


def fixture(source="system", count=3, *, heartbeat=None):
    if heartbeat is None:
        heartbeat = NOW
    entries = []
    for index in range(count):
        token = f"{index + 1:032x}"
        path = f"/gnu/store/{token}-package-{index}-1.0"
        entries.append(
            {
                "path": path,
                "drv": f"/gnu/store/{token}-package-{index}-1.0.drv",
                "name": f"package-{index}",
                "version": "1.0",
                "output": "out",
                "kind": "package" if index else "output",
                "direct": index == 1,
            }
        )
    return {
        "schema": 1,
        "source": source,
        "system": "x86_64-linux",
        "generated_at": (heartbeat - timedelta(minutes=1)).strftime(
            "%Y-%m-%dT%H:%M:%SZ"
        ),
        "heartbeat_at": heartbeat.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "root_drv": entries[0]["drv"],
        "root_output": entries[0]["path"],
        "entries": entries,
    }


class RenderTests(unittest.TestCase):
    def test_exact_targets_state_badges_and_translation(self):
        render = load(MODULE, "farm_render_test")
        system = fixture()
        home = fixture("home")
        shared = system["entries"][1]["path"]
        targets = catalog.merge_targets(
            [system, home],
            [{"path": shared, "name": "package-1", "job": "channel.package-1"}],
        )
        public = {shared}
        present = {entry["path"] for entry in system["entries"][:2]}
        pages = render.render_source_pages(
            system, targets, public, present, {}, NOW, "en", "2026-10-14 02:30 UTC"
        )
        english = pages["system/index.html"].decode("utf-8")
        self.assertIn("System", english)
        self.assertIn("Direct package", english)
        self.assertIn("Closure output", english)
        self.assertIn("Public NAR route", english)
        self.assertIn("Present on CT126", english)
        self.assertIn("Not present on CT126", english)
        self.assertIn("Channel", english)
        self.assertIn("Home", english)
        self.assertIn('<span class="source-badge">System</span>', english)
        self.assertIn(shared, english)
        self.assertNotIn("/home/berkeley", english)
        self.assertNotIn("<script", english.lower())
        self.assertIn("If this heartbeat is over 24 hours old", english)
        portuguese = render.render_source_pages(
            home, targets, public, present, {}, NOW, "pt-br", "2026-10-14 02:30 UTC"
        )["pt-br/home/index.html"].decode("utf-8")
        self.assertIn("Pacotes diretos", portuguese)
        self.assertIn("Rota NAR pública", portuguese)
        self.assertIn('lang="pt-BR"', portuguese)
        self.assertIn("Se esta confirmação tiver mais de 24 horas", portuguese)

    def test_static_pagination_keeps_every_target(self):
        render = load(MODULE, "farm_render_pagination_test")
        system = fixture(count=131)
        targets = catalog.merge_targets([system], [])
        pages = render.render_source_pages(
            system, targets, set(), set(), {}, NOW, "en", "date", page_size=40
        )
        self.assertEqual(len(pages), 4)
        self.assertIn("system/index.html", pages)
        self.assertIn("system/page/4/index.html", pages)
        combined = "".join(page.decode("utf-8") for page in pages.values())
        for entry in system["entries"]:
            self.assertEqual(
                combined.count(f'<code class="store-path">{entry["path"]}</code>'), 1
            )
        self.assertIn('href="/system/page/2/"', pages["system/index.html"].decode())

    def test_old_accepted_inventory_is_visible_but_marked_stale(self):
        render = load(MODULE, "farm_render_stale_test")
        system = fixture(heartbeat=NOW - timedelta(hours=25))
        pages = render.render_source_pages(
            system,
            catalog.merge_targets([system], []),
            set(),
            set(),
            {},
            NOW,
            "en",
            "date",
        )
        self.assertIn("Inventory stale", pages["system/index.html"].decode())

    @unittest.skipUnless(shutil.which("chromium"), "Chromium is not available")
    def test_mobile_browser_has_black_background_and_no_horizontal_overflow(self):
        chromium = shutil.which("chromium")
        assert chromium is not None
        render = load(MODULE, "farm_render_browser_test")
        system = fixture(count=22)
        pages = render.render_source_pages(
            system,
            catalog.merge_targets([system], []),
            set(),
            set(),
            {},
            NOW,
            "en",
            "date",
        )
        html = pages["system/index.html"].decode("utf-8")
        self.assertNotIn("<script", html.lower())
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "system").mkdir()
            shutil.copyfile(ROOT / "etc/build-farm/site/style.css", root / "style.css")
            probe = (
                "<script>document.body.dataset.background="
                "getComputedStyle(document.body).backgroundColor;"
                "document.body.dataset.overflow="
                "document.documentElement.scrollWidth > document.documentElement.clientWidth;"
                "</script>"
            )
            (root / "system/index.html").write_text(
                html.replace('href="/style.css"', 'href="../style.css"').replace(
                    "</body>", probe + "</body>"
                ),
                encoding="utf-8",
            )
            result = subprocess.run(
                [
                    chromium,
                    "--headless",
                    "--no-sandbox",
                    "--disable-gpu",
                    "--disable-dev-shm-usage",
                    f"--user-data-dir={root / 'profile'}",
                    "--window-size=320,800",
                    "--dump-dom",
                    (root / "system/index.html").as_uri(),
                ],
                capture_output=True,
                text=True,
                timeout=30,
                check=True,
            )
            self.assertIn('data-background="rgb(0, 0, 0)"', result.stdout)
            self.assertIn('data-overflow="false"', result.stdout)


if __name__ == "__main__":
    unittest.main()
