"""Behavior checks for the public, static build-farm status snapshot."""

import importlib.util
import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import time
import unittest
from datetime import datetime, timedelta, timezone
from email.message import Message
from pathlib import Path
from unittest.mock import Mock, patch
from urllib.error import HTTPError, URLError

MODULE = Path(__file__).resolve().parents[1] / "etc/build-farm/site/generate.py"
SPEC = importlib.util.spec_from_file_location("farm_site_generate", MODULE)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("could not load farm-site generator")
farm_site = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(farm_site)

STORE = "/gnu/store/29cg9q8k2yzryzi7df79s0ngyvdsx7gd-btp-0.7"
NAR_HASH = "129rq55gfyvk77rrznn7rf2rmamsnfrpzjcr2f32q8gbx9md0rmf"
CSV = (
    "989,1791920000,applications.btp.x86_64-linux,0,1,btp-0.7,0,1791861508,1791861509,out,"
    + STORE
    + "\n989,1791920000,applications.zupt.x86_64-linux,-1,10,zupt-5.2.9,-1,1791923504,0,out,"
    + "/gnu/store/4hkfjrkwa07m9yvy8kxc39v2aablrmsx-zupt-5.2.9\n"
    + "989,1791920000,reporting.arelle.x86_64-linux,2,50,arelle-2.46.0,2,0,1791923548,out,"
    + "/gnu/store/0jnnbjw4iqklpwmwgv554nypp0q1n1lr-arelle-2.46.0\n"
)


def minimal_manifest(source):
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    return {
        "schema": 1,
        "source": source,
        "system": "x86_64-linux",
        "generated_at": timestamp,
        "heartbeat_at": timestamp,
        "root_drv": STORE + ".drv",
        "root_output": STORE,
        "entries": [
            {
                "path": STORE,
                "drv": STORE + ".drv",
                "name": "btp",
                "version": "0.7",
                "output": "out",
                "kind": "package",
                "direct": True,
            }
        ],
    }


class FarmSiteTests(unittest.TestCase):
    @staticmethod
    def seed_previous(root):
        previous = root / "releases" / "old"
        (previous / "pt-br").mkdir(parents=True)
        (previous / "index.html").write_text("old English", encoding="utf-8")
        (previous / "pt-br/index.html").write_text("old Portuguese", encoding="utf-8")
        (previous / "style.css").write_text("old CSS", encoding="utf-8")
        (root / "current").symlink_to("releases/old", target_is_directory=True)

    def test_snapshot_keeps_success_started_and_failure(self):
        snapshot = farm_site.parse_snapshot_csv(CSV)
        self.assertEqual(snapshot["evaluation"], 989)
        self.assertEqual(len(snapshot["packages"]), 3)
        self.assertEqual(
            [item["build_status"] for item in snapshot["packages"]], [0, -1, 2]
        )

    def test_duplicate_job_is_not_counted_twice(self):
        with self.assertRaises(ValueError):
            farm_site.parse_snapshot_csv(CSV + CSV.splitlines(keepends=True)[0])

    def test_exact_signed_public_narinfo_required(self):
        valid = (
            f"StorePath: {STORE}\nNarHash: sha256:{NAR_HASH}\n"
            "URL: nar/zstd/29cg9q8k2yzryzi7df79s0ngyvdsx7gd-btp-0.7\n"
            "Signature: 1;guix-substitute;abc\n"
        )
        self.assertTrue(farm_site.validate_narinfo(STORE, valid))
        with self.assertRaises(ValueError):
            farm_site.validate_narinfo(STORE, valid.replace(STORE, STORE + "-wrong"))
        with self.assertRaises(ValueError):
            farm_site.validate_narinfo(
                STORE, valid.replace("Signature:", "NoSignature:")
            )
        with self.assertRaises(ValueError):
            farm_site.validate_narinfo(STORE, valid.replace(NAR_HASH, "abc"))
        with self.assertRaises(ValueError):
            farm_site.validate_narinfo(
                STORE,
                valid.replace(
                    "nar/zstd/29cg9q8k2yzryzi7df79s0ngyvdsx7gd-btp-0.7", "nar/"
                ),
            )

    def test_guix_narinfo_may_offer_multiple_compressions(self):
        valid = (
            f"StorePath: {STORE}\nNarHash: sha256:{NAR_HASH}\nReferences: \n"
            "Signature: 1;guix-substitute;abc\n"
            "URL: nar/zstd/29cg9q8k2yzryzi7df79s0ngyvdsx7gd-btp-0.7\n"
            "Compression: zstd\nFileSize: 100\n"
            "URL: nar/gzip/29cg9q8k2yzryzi7df79s0ngyvdsx7gd-btp-0.7\n"
            "Compression: gzip\nFileSize: 200\n"
        )
        self.assertTrue(farm_site.validate_narinfo(STORE, valid))
        with self.assertRaises(ValueError):
            farm_site.validate_narinfo(STORE, valid + f"StorePath: {STORE}\n")

    def test_only_http_404_means_not_published(self):
        with patch.object(farm_site, "build_opener") as build_opener:
            build_opener.return_value.open.side_effect = HTTPError(
                "https://substitutes.securityops.co/x.narinfo",
                404,
                "missing",
                Message(),
                None,
            )
            self.assertFalse(farm_site.check_public_output(STORE))
            build_opener.return_value.open.side_effect = HTTPError(
                "https://substitutes.securityops.co/x.narinfo",
                503,
                "outage",
                Message(),
                None,
            )
            with self.assertRaises(HTTPError):
                farm_site.check_public_output(STORE)

    def test_narinfo_without_reachable_nar_is_not_available(self):
        document = (
            f"StorePath: {STORE}\nNarHash: sha256:{NAR_HASH}\n"
            "URL: nar/zstd/fixture\nSignature: 1;guix-substitute;abc\n"
        ).encode()

        class Response:
            status = 200

            def __enter__(self):
                return self

            def __exit__(self, *args):
                return False

            def read(self, size):
                return document[:size]

        class FakeOpener:
            def open(self, request, timeout):
                if request.full_url.endswith(".narinfo"):
                    return Response()
                raise HTTPError(request.full_url, 404, "missing NAR", Message(), None)

        with patch.object(farm_site, "build_opener", return_value=FakeOpener()):
            self.assertFalse(farm_site.check_public_output(STORE))

    def test_public_catalog_uses_same_publisher_over_lan_and_external_witness(self):
        snapshot = farm_site.parse_snapshot_csv(CSV)
        calls = []

        def probe(path, base_url=farm_site.PUBLIC_URL):
            calls.append((path, base_url))
            return path == STORE

        with patch.object(farm_site, "check_public_output", side_effect=probe):
            self.assertEqual(farm_site.published_outputs(snapshot), {STORE})
        self.assertIn((STORE, farm_site.PUBLIC_CHECK_URL), calls)
        self.assertIn((STORE, farm_site.PUBLIC_URL), calls)

        def unreachable(path, base_url=farm_site.PUBLIC_URL):
            if base_url == farm_site.PUBLIC_URL:
                raise URLError("external bridge down")
            return path == STORE

        with (
            patch.object(farm_site, "check_public_output", side_effect=unreachable),
            self.assertRaises(URLError),
        ):
            farm_site.published_outputs(snapshot)

    def test_each_public_claim_requires_its_own_external_narinfo(self):
        snapshot = farm_site.parse_snapshot_csv(CSV)
        first = snapshot["packages"][0]["path"]
        second = snapshot["packages"][1]["path"]
        calls = []

        def probe(path, base_url=farm_site.PUBLIC_URL):
            calls.append((path, base_url))
            if base_url == farm_site.PUBLIC_CHECK_URL:
                return True
            return path == first

        with patch.object(farm_site, "check_public_output", side_effect=probe):
            self.assertEqual(farm_site.published_outputs(snapshot), {first})
        self.assertIn((second, farm_site.PUBLIC_URL), calls)

    def test_large_catalog_stops_probing_after_first_failed_batch(self):
        snapshot = farm_site.parse_snapshot_csv(CSV)
        snapshot["packages"] = [
            {**snapshot["packages"][0], "path": f"/gnu/store/{index:032x}-pkg"}
            for index in range(100)
        ]
        calls = []

        def unavailable(path, base_url=farm_site.PUBLIC_URL):
            calls.append(path)
            if path == snapshot["packages"][0]["path"]:
                time.sleep(0.08)
                raise URLError("publisher unavailable")
            time.sleep(0.002)
            return False

        with (
            patch.object(farm_site, "check_public_output", side_effect=unavailable),
            self.assertRaises(URLError),
        ):
            farm_site.published_outputs(snapshot)
        self.assertLessEqual(len(calls), 48)

    def test_network_failure_does_not_publish_a_new_snapshot(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.seed_previous(root)
            with (
                patch.object(farm_site.subprocess, "run") as run,
                patch.object(
                    farm_site, "published_outputs", side_effect=URLError("down")
                ),
                patch.object(
                    farm_site,
                    "read_manifest",
                    side_effect=[minimal_manifest("system"), minimal_manifest("home")],
                ),
                patch.object(sys, "argv", ["generate.py", "--output-dir", str(root)]),
            ):
                run.return_value.stdout = CSV
                with self.assertRaises(URLError):
                    farm_site.main()
            self.assertEqual((root / "current/index.html").read_text(), "old English")
            self.assertEqual(
                (root / "current/pt-br/index.html").read_text(), "old Portuguese"
            )

    def test_distribution_and_build_are_independent(self):
        items = farm_site.parse_snapshot_csv(CSV)["packages"]
        self.assertEqual(farm_site.color_state(items[0], False, False), "unavailable")
        self.assertEqual(farm_site.color_state(items[0], False, True), "stored")
        self.assertEqual(farm_site.color_state(items[0], True, False), "available")
        self.assertEqual(farm_site.color_state(items[1], False, False), "building")
        self.assertEqual(farm_site.color_state(items[2], False, False), "unavailable")

    def test_success_without_valid_store_path_is_not_present(self):
        item = farm_site.parse_snapshot_csv(CSV)["packages"][0]
        self.assertEqual(farm_site.color_state(item, False, False), "unavailable")

    def test_local_store_probe_uses_one_batch_and_rejects_unknown_paths(self):
        paths = [STORE, "/gnu/store/4hkfjrkwa07m9yvy8kxc39v2aablrmsx-zupt-5.2.9"]
        with patch.object(farm_site.subprocess, "run") as run:
            run.return_value.stdout = paths[1] + "\n"
            self.assertEqual(farm_site.valid_local_outputs(paths), {STORE})
            self.assertEqual(run.call_count, 1)
            self.assertEqual(
                run.call_args.args[0],
                [
                    "/var/guix/profiles/per-user/root/current-guix/bin/guix",
                    "archive",
                    "--missing",
                ],
            )
            run.return_value.stdout = (
                "/gnu/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-foreign\n"
            )
            with self.assertRaises(ValueError):
                farm_site.valid_local_outputs(paths)

    def test_local_probe_failure_keeps_previous_release(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.seed_previous(root)
            with (
                patch.object(farm_site.subprocess, "run") as run,
                patch.object(farm_site, "published_outputs", return_value=set()),
                patch.object(
                    farm_site,
                    "read_manifest",
                    side_effect=[minimal_manifest("system"), minimal_manifest("home")],
                ),
                patch.object(sys, "argv", ["generate.py", "--output-dir", str(root)]),
            ):
                run.side_effect = [
                    Mock(stdout=CSV),
                    subprocess.CalledProcessError(1, "guix"),
                ]
                with self.assertRaises(subprocess.CalledProcessError):
                    farm_site.main()
            self.assertEqual((root / "current/index.html").read_text(), "old English")

    def test_present_metric_counts_jobs_not_unrelated_paths(self):
        snapshot = farm_site.parse_snapshot_csv(CSV)
        html = farm_site.render_page(
            snapshot,
            set(),
            {STORE, "/gnu/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-foreign"},
            "en",
            "date",
        )
        self.assertIn(
            '<dt class="label">Present on farm</dt><dd class="number">1</dd>', html
        )

    def test_successes_presence_and_publication_have_separate_counts(self):
        snapshot = farm_site.parse_snapshot_csv(CSV)
        base = snapshot["packages"][0]
        packages = []
        for index in range(180):
            item = dict(base)
            item["job"] = f"applications.pkg-{index}.x86_64-linux"
            item["name"] = f"pkg-{index}-1.0"
            item["path"] = f"/gnu/store/{index:032x}-pkg-{index}-1.0"
            item["job_status"] = 0 if index < 167 else 1 if index < 172 else 2
            item["build_status"] = item["job_status"]
            packages.append(item)
        snapshot["packages"] = packages
        public = {item["path"] for item in packages[:3]}
        present = {item["path"] for item in packages[:167]}
        html = farm_site.render_page(snapshot, public, present, "en", "date")
        self.assertIn(
            '<dt class="label">Builds succeeded</dt><dd class="number">167</dd>', html
        )
        self.assertIn(
            '<dt class="label">Present on farm</dt><dd class="number">167</dd>', html
        )
        self.assertIn(
            '<dt class="label">Public NAR routes</dt><dd class="number">3</dd>',
            html,
        )
        self.assertIn(
            '<dt class="label">Failed or blocked</dt><dd class="number">13</dd>', html
        )
        self.assertEqual(html.count('class="package stored"'), 164)
        self.assertNotIn("awaiting publication", html)

    def test_divergent_started_status_has_matching_color_and_reason(self):
        snapshot = farm_site.parse_snapshot_csv(CSV)
        snapshot["packages"][0]["build_status"] = -1
        html = farm_site.render_page(snapshot, set(), set(), "en", "date")
        self.assertIn('class="package building"', html)
        self.assertNotIn("Build succeeded · awaiting publication", html)
        self.assertIn("Build in progress", html)

    def test_render_is_translated_escaped_and_script_free(self):
        snapshot = farm_site.parse_snapshot_csv(CSV)
        snapshot["packages"][0]["name"] = '<script>alert("x")</script>'
        english = farm_site.render_page(
            snapshot, {STORE}, {STORE}, "en", "2026-10-13 23:00 UTC"
        )
        portuguese = farm_site.render_page(
            snapshot, {STORE}, {STORE}, "pt-br", "2026-10-13 23:00 UTC"
        )
        self.assertIn("Public NAR routes", english)
        self.assertIn('<link rel="icon" href="data:,">', english)
        self.assertIn("Rotas NAR públicas", portuguese)
        self.assertIn("&lt;script&gt;", english)
        self.assertNotIn("<script", english.lower())
        self.assertIn('class="package available"', english)
        self.assertIn('class="package building"', english)
        self.assertIn('class="package unavailable"', english)
        self.assertIn('lang="pt-BR"', portuguese)
        self.assertIn("Estado dos pacotes", portuguese)
        self.assertIn("Mapa de pacotes", portuguese)
        self.assertIn("Public NAR route · Build succeeded", english)
        self.assertNotIn("awaiting publication", english)
        self.assertNotIn("publicação pendente", portuguese)

    def test_editorial_page_has_localized_heading_and_skip_navigation(self):
        snapshot = farm_site.parse_snapshot_csv(CSV)
        english = farm_site.render_page(snapshot, {STORE}, {STORE}, "en", "date")
        portuguese = farm_site.render_page(snapshot, {STORE}, {STORE}, "pt-br", "date")
        self.assertIn(
            '<a class="skip-link" href="#packages">Skip to packages</a>', english
        )
        self.assertIn(
            '<a class="skip-link" href="#packages">Ir para os pacotes</a>',
            portuguese,
        )
        self.assertIn(
            '<h1 id="page-title" class="animated-title">Build farm</h1>', english
        )
        self.assertIn(
            '<h1 id="page-title" class="animated-title">Compilações</h1>',
            portuguese,
        )
        self.assertIn('<div id="packages" class="groups">', english)
        self.assertIn('<div id="packages" class="groups">', portuguese)
        self.assertNotIn("orb-outer", english)
        self.assertNotIn("LIVE BUILD INTELLIGENCE", english)

    def test_browser_renders_black_background_and_compact_package_rows(self):
        chromium = shutil.which("chromium")
        if chromium is None:
            self.skipTest("Chromium is not available")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            shutil.copyfile(MODULE.with_name("style.css"), root / "style.css")
            (root / "index.html").write_text(
                '<!doctype html><meta name="viewport" content="width=device-width, initial-scale=1">'
                '<link rel="stylesheet" href="style.css"><div class="page-shell">'
                '<h1 class="animated-title">Build farm</h1>'
                '<main><div class="package-grid"><article class="package available">'
                '<span class="tile"></span><div class="package-info"><h3>example-1.0</h3>'
                '<p class="job">applications.example.x86_64-linux</p>'
                '<p class="status">Published</p></div></article></div></main></div>'
                '<script>const shell=document.querySelector(".page-shell");'
                'const card=document.querySelector(".package");'
                "document.body.dataset.background=getComputedStyle(shell).backgroundColor;"
                "document.body.dataset.backgroundImage=getComputedStyle(shell).backgroundImage;"
                "document.body.dataset.cardHeight=Math.round(card.getBoundingClientRect().height);"
                'document.body.dataset.titleOpacity=getComputedStyle(document.querySelector(".animated-title")).opacity;'
                "document.body.dataset.font=getComputedStyle(document.body).fontFamily;"
                "</script>",
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
                    "--window-size=1280,800",
                    "--dump-dom",
                    (root / "index.html").as_uri(),
                ],
                capture_output=True,
                text=True,
                timeout=30,
                check=True,
            )
            self.assertIn('data-background="rgb(0, 0, 0)"', result.stdout)
            self.assertIn('data-background-image="none"', result.stdout)
            self.assertIn('data-card-height="', result.stdout)
            card_height = int(
                result.stdout.split('data-card-height="', 1)[1].split('"', 1)[0]
            )
            self.assertLessEqual(card_height, 180)
            title_opacity = float(
                result.stdout.split('data-title-opacity="', 1)[1].split('"', 1)[0]
            )
            self.assertGreaterEqual(title_opacity, 0.8)
            self.assertIn("monospace", result.stdout)

    def test_failed_render_keeps_previous_pages(self):
        snapshot = farm_site.parse_snapshot_csv(CSV)
        snapshot["packages"][0]["name"] = ""
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.seed_previous(root)
            with self.assertRaises(ValueError):
                farm_site.write_pages(snapshot, {STORE}, root, "date")
            self.assertEqual((root / "current/index.html").read_text(), "old English")
            self.assertEqual(
                (root / "current/pt-br/index.html").read_text(), "old Portuguese"
            )

    def test_one_atomic_switch_publishes_both_languages_and_css(self):
        snapshot = farm_site.parse_snapshot_csv(CSV)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.seed_previous(root)
            real_replace = farm_site.os.replace
            replacements = []

            def fail_second_replace(source, target):
                replacements.append((source, target))
                if len(replacements) > 1:
                    raise OSError("second publication step failed")
                return real_replace(source, target)

            with patch.object(farm_site.os, "replace", side_effect=fail_second_replace):
                farm_site.write_pages(snapshot, {STORE}, root, "new date")
            self.assertEqual(len(replacements), 1)
            self.assertIn("new date", (root / "current/index.html").read_text())
            self.assertIn("new date", (root / "current/pt-br/index.html").read_text())
            self.assertIn(":root", (root / "current/style.css").read_text())

    def test_atomic_release_includes_complete_catalog_pages(self):
        snapshot = farm_site.parse_snapshot_csv(CSV)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.seed_previous(root)
            farm_site.write_pages(
                snapshot,
                {STORE},
                root,
                "new date",
                present_paths={STORE},
                extra_pages={
                    "system/index.html": b"System page",
                    "system/page/10/index.html": b"System page ten",
                    "pt-br/system/index.html": b"Pagina Sistema",
                },
            )
            self.assertEqual(
                (root / "current/system/index.html").read_bytes(), b"System page"
            )
            self.assertEqual(
                (root / "current/system/page/10/index.html").read_bytes(),
                b"System page ten",
            )
            self.assertEqual(
                (root / "current/pt-br/system/index.html").read_bytes(),
                b"Pagina Sistema",
            )
            self.assertIn('href="/system/"', (root / "current/index.html").read_text())
            self.assertIn(
                'href="/pt-br/system/"', (root / "current/pt-br/index.html").read_text()
            )

    def test_main_adds_opt_in_map_without_scripts_on_clean_pages(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.seed_previous(root)
            with (
                patch.object(
                    farm_site.subprocess, "run", return_value=Mock(stdout=CSV)
                ),
                patch.object(
                    farm_site,
                    "read_manifest",
                    side_effect=[minimal_manifest("system"), minimal_manifest("home")],
                ),
                patch.object(farm_site, "published_outputs", return_value={STORE}),
                patch.object(farm_site, "valid_local_outputs", return_value={STORE}),
                patch.object(sys, "argv", ["generate.py", "--output-dir", str(root)]),
            ):
                farm_site.main()
            current = root / "current"
            self.assertIn('href="/explore/"', (current / "index.html").read_text())
            self.assertIn(
                'href="/pt-br/explore/"', (current / "pt-br/index.html").read_text()
            )
            self.assertNotIn("<script", (current / "index.html").read_text())
            self.assertNotIn("<script", (current / "system/index.html").read_text())
            self.assertIn(
                'src="/explore/app.js"', (current / "explore/index.html").read_text()
            )
            self.assertTrue((current / "pt-br/explore/index.html").is_file())
            data = json.loads((current / "explore/data.json").read_text())["sources"][
                "channel"
            ]
            self.assertEqual(data["total"], 3)
            self.assertNotIn("root_drv", data)
            self.assertNotIn(
                "/home/berkeley", (current / "explore/data.json").read_text()
            )

    def test_channel_active_shared_output_is_building_on_clean_home_page(self):
        system = minimal_manifest("system")
        home = minimal_manifest("home")
        shared = farm_site.parse_snapshot_csv(CSV)["packages"][1]["path"]
        home["root_drv"] = shared + ".drv"
        home["root_output"] = shared
        home["entries"][0].update(
            path=shared, drv=shared + ".drv", name="zupt", version="5.2.9"
        )
        with tempfile.TemporaryDirectory() as directory:
            with (
                patch.object(
                    farm_site.subprocess, "run", return_value=Mock(stdout=CSV)
                ),
                patch.object(farm_site, "read_manifest", side_effect=[system, home]),
                patch.object(farm_site, "published_outputs", return_value=set()),
                patch.object(farm_site, "valid_local_outputs", return_value=set()),
                patch.object(sys, "argv", ["generate.py", "--output-dir", directory]),
            ):
                farm_site.main()
            current = Path(directory) / "current"
            self.assertIn(
                '<article class="package building">',
                (current / "home/index.html").read_text(),
            )
            data = json.loads((current / "explore/data.json").read_text())
            self.assertEqual(data["sources"]["home"]["nodes"][0]["status"], "building")

    def test_home_activity_colors_shared_channel_card_building(self):
        snapshot = farm_site.parse_snapshot_csv(CSV)
        page = farm_site.render_page(
            snapshot,
            set(),
            set(),
            "en",
            "2026-10-14 22:00 UTC",
            active_paths={STORE: datetime.now(timezone.utc)},
        )
        btp_card_start = page.split("<h3>btp-0.7</h3>", 1)[0].rsplit("<article", 1)[1]
        self.assertIn('class="package building"', btp_card_start)
        self.assertIn('Building now</dt><dd class="number">2</dd>', page)

    def test_homepage_counts_all_unique_targets_not_just_channel_jobs(self):
        system = minimal_manifest("system")
        home = minimal_manifest("home")
        for manifest, digit in ((system, "d"), (home, "e")):
            path = f"/gnu/store/{digit * 32}-fixture"
            manifest["root_drv"] = path + ".drv"
            manifest["root_output"] = path
            manifest["entries"][0]["path"] = path
            manifest["entries"][0]["drv"] = path + ".drv"
        target_paths = {STORE, system["root_output"], home["root_output"]}
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with (
                patch.object(
                    farm_site.subprocess, "run", return_value=Mock(stdout=CSV)
                ),
                patch.object(farm_site, "read_manifest", side_effect=[system, home]),
                patch.object(farm_site, "published_outputs", return_value=target_paths),
                patch.object(
                    farm_site, "valid_local_outputs", return_value=target_paths
                ),
                patch.object(sys, "argv", ["generate.py", "--output-dir", str(root)]),
            ):
                farm_site.main()
            english = (root / "current/index.html").read_text()
            portuguese = (root / "current/pt-br/index.html").read_text()
            self.assertIn(
                '<dt class="label">Unique target outputs</dt><dd class="number">5</dd>',
                english,
            )
            self.assertIn(
                '<dt class="label">Public NAR routes</dt><dd class="number">3</dd>',
                english,
            )
            self.assertIn("Channel jobs <strong>3</strong>", english)
            self.assertIn("Saídas únicas", portuguese)

    def test_snapshot_syncs_release_directories_and_pointer(self):
        snapshot = farm_site.parse_snapshot_csv(CSV)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            real_fsync = farm_site.os.fsync
            synced_directories = set()

            def record_fsync(descriptor):
                if stat.S_ISDIR(os.fstat(descriptor).st_mode):
                    synced_directories.add(
                        Path(os.readlink(f"/proc/self/fd/{descriptor}"))
                    )
                return real_fsync(descriptor)

            with patch.object(farm_site.os, "fsync", side_effect=record_fsync):
                farm_site.write_pages(
                    snapshot,
                    {STORE},
                    root,
                    "date",
                    extra_pages={"system/page/10/index.html": b"page"},
                )
            release = (root / "current").resolve()
            self.assertIn(release / "system/page/10", synced_directories)
            self.assertIn(release / "system", synced_directories)
            self.assertIn(release, synced_directories)
            self.assertIn(root / "releases", synced_directories)
            self.assertIn(root, synced_directories)

    def test_read_manifest_accepts_old_saved_inventory_but_not_bad_source(self):
        stamp = datetime.now(timezone.utc) - timedelta(hours=25)
        timestamp = stamp.strftime("%Y-%m-%dT%H:%M:%SZ")
        path = "/gnu/store/" + "a" * 32 + "-fixture"
        value = {
            "schema": 1,
            "source": "system",
            "system": "x86_64-linux",
            "generated_at": timestamp,
            "heartbeat_at": timestamp,
            "root_drv": path + ".drv",
            "root_output": path,
            "entries": [
                {
                    "path": path,
                    "drv": path + ".drv",
                    "name": "fixture",
                    "version": "1",
                    "output": "out",
                    "kind": "output",
                    "direct": False,
                }
            ],
        }
        with tempfile.TemporaryDirectory() as directory:
            inbox = Path(directory)
            (inbox / "system.json").write_text(json.dumps(value), encoding="utf-8")
            self.assertEqual(
                farm_site.read_manifest(inbox, "system")["source"], "system"
            )
            (inbox / "home.json").write_text(json.dumps(value), encoding="utf-8")
            with self.assertRaises(ValueError):
                farm_site.read_manifest(inbox, "home")

    def test_activity_is_exact_fresh_and_never_inferred_from_manifest(self):
        manifest = minimal_manifest("system")
        now = datetime.now(timezone.utc)
        with tempfile.TemporaryDirectory() as directory:
            inbox = Path(directory)
            self.assertEqual(farm_site.read_activity(inbox, manifest, now), {})
            activity = {
                "schema": 1,
                "source": "system",
                "updated_at": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
                "active_outputs": [STORE],
            }
            path = inbox / "system-activity.json"
            path.write_text(json.dumps(activity), encoding="utf-8")
            self.assertEqual(
                set(farm_site.read_activity(inbox, manifest, now)), {STORE}
            )
            self.assertEqual(
                farm_site.read_activity(inbox, manifest, now + timedelta(minutes=16)),
                {},
            )
            activity["active_outputs"] = ["/gnu/store/" + "c" * 32 + "-unknown"]
            path.write_text(json.dumps(activity), encoding="utf-8")
            self.assertEqual(farm_site.read_activity(inbox, manifest, now), {})

    def test_fresh_activity_paints_only_the_exact_unavailable_target_yellow(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            now = datetime.now(timezone.utc)
            home = minimal_manifest("home")
            home_path = "/gnu/store/" + "d" * 32 + "-home"
            home["root_output"] = home_path
            home["root_drv"] = home_path + ".drv"
            home["entries"][0]["path"] = home_path
            home["entries"][0]["drv"] = home_path + ".drv"
            with (
                patch.object(farm_site.subprocess, "run") as run,
                patch.object(
                    farm_site,
                    "read_manifest",
                    side_effect=[minimal_manifest("system"), home],
                ),
                patch.object(
                    farm_site,
                    "read_activity",
                    side_effect=[{STORE: now}, {}],
                ),
                patch.object(farm_site, "published_outputs", return_value=set()),
                patch.object(farm_site, "valid_local_outputs", return_value=set()),
                patch.object(sys, "argv", ["generate.py", "--output-dir", str(root)]),
            ):
                run.return_value.stdout = CSV
                farm_site.main()
            self.assertIn(
                'class="package building"',
                (root / "current/system/index.html").read_text(),
            )
            self.assertNotIn(
                'class="package building"',
                (root / "current/home/index.html").read_text(),
            )

    def test_full_refresh_writes_system_and_home_in_both_languages(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with (
                patch.object(farm_site.subprocess, "run") as run,
                patch.object(
                    farm_site,
                    "read_manifest",
                    side_effect=[minimal_manifest("system"), minimal_manifest("home")],
                ),
                patch.object(farm_site, "published_outputs", return_value={STORE}),
                patch.object(farm_site, "valid_local_outputs", return_value={STORE}),
                patch.object(sys, "argv", ["generate.py", "--output-dir", str(root)]),
            ):
                run.return_value.stdout = CSV
                farm_site.main()
            for relative in (
                "system/index.html",
                "home/index.html",
                "pt-br/system/index.html",
                "pt-br/home/index.html",
            ):
                self.assertTrue((root / "current" / relative).is_file(), relative)
            self.assertIn(STORE, (root / "current/system/index.html").read_text())
            self.assertIn('href="/home/"', (root / "current/index.html").read_text())

    def test_missing_inventories_publish_channel_without_false_counts(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with (
                patch.object(
                    farm_site.subprocess, "run", return_value=Mock(stdout=CSV)
                ),
                patch.object(
                    farm_site,
                    "read_manifest",
                    side_effect=[FileNotFoundError(), FileNotFoundError()],
                ),
                patch.object(farm_site, "published_outputs", return_value={STORE}),
                patch.object(farm_site, "valid_local_outputs", return_value={STORE}),
                patch.object(sys, "argv", ["generate.py", "--output-dir", str(root)]),
            ):
                farm_site.main()
            current = root / "current"
            english = (current / "index.html").read_text()
            portuguese = (current / "pt-br/index.html").read_text()
            self.assertIn("System · Inventory in preparation", english)
            self.assertIn("Sistema · Inventário em preparação", portuguese)
            self.assertIn("Channel targets only", english)
            self.assertNotIn('href="/system/"', english)
            self.assertNotIn('href="/home/"', english)
            self.assertNotIn("<script", english)
            self.assertFalse((current / "system/index.html").exists())
            self.assertFalse((current / "home/index.html").exists())
            data = json.loads((current / "explore/data.json").read_text())
            self.assertEqual(data["sources"]["channel"]["total"], 3)
            self.assertTrue(data["sources"]["system"]["inventory_pending"])
            self.assertTrue(data["sources"]["home"]["inventory_pending"])
            self.assertFalse(data["sources"]["channel"]["inventory_pending"])

    def test_one_manifest_adds_only_its_verified_catalog(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with (
                patch.object(
                    farm_site.subprocess, "run", return_value=Mock(stdout=CSV)
                ),
                patch.object(
                    farm_site,
                    "read_manifest",
                    side_effect=[minimal_manifest("system"), FileNotFoundError()],
                ),
                patch.object(farm_site, "published_outputs", return_value={STORE}),
                patch.object(farm_site, "valid_local_outputs", return_value={STORE}),
                patch.object(sys, "argv", ["generate.py", "--output-dir", str(root)]),
            ):
                farm_site.main()
            current = root / "current"
            english = (current / "index.html").read_text()
            self.assertIn('href="/system/"', english)
            self.assertIn("Home · Inventory in preparation", english)
            self.assertNotIn('href="/home/"', english)
            self.assertTrue((current / "system/index.html").is_file())
            self.assertFalse((current / "home/index.html").exists())
            data = json.loads((current / "explore/data.json").read_text())
            self.assertFalse(data["sources"]["system"]["inventory_pending"])
            self.assertTrue(data["sources"]["home"]["inventory_pending"])

    def test_malformed_present_inventory_keeps_previous_release(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.seed_previous(root)
            with (
                patch.object(
                    farm_site.subprocess, "run", return_value=Mock(stdout=CSV)
                ),
                patch.object(
                    farm_site,
                    "read_manifest",
                    side_effect=[
                        ValueError("malformed inventory"),
                        FileNotFoundError(),
                    ],
                ),
                patch.object(sys, "argv", ["generate.py", "--output-dir", str(root)]),
                self.assertRaisesRegex(ValueError, "malformed inventory"),
            ):
                farm_site.main()
            self.assertEqual((root / "current/index.html").read_text(), "old English")

    def test_failed_atomic_switch_keeps_all_previous_assets(self):
        snapshot = farm_site.parse_snapshot_csv(CSV)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.seed_previous(root)
            with (
                patch.object(farm_site.os, "replace", side_effect=OSError("disk")),
                self.assertRaises(OSError),
            ):
                farm_site.write_pages(snapshot, {STORE}, root, "new date")
            self.assertEqual((root / "current/index.html").read_text(), "old English")
            self.assertEqual(
                (root / "current/pt-br/index.html").read_text(), "old Portuguese"
            )
            self.assertEqual((root / "current/style.css").read_text(), "old CSS")

    def test_generated_pages_are_readable_by_static_server(self):
        snapshot = farm_site.parse_snapshot_csv(CSV)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            farm_site.write_pages(snapshot, {STORE}, root, "date")
            self.assertEqual(
                (root / "current/index.html").stat().st_mode & 0o777, 0o644
            )
            self.assertEqual(
                (root / "current/pt-br/index.html").stat().st_mode & 0o777, 0o644
            )
            self.assertEqual((root / "current/style.css").stat().st_mode & 0o777, 0o644)


if __name__ == "__main__":
    unittest.main()
