"""Publish a static Cuirass snapshot after checking the public substitute server."""

import argparse
import csv
import importlib.util
import io
import os
import re
import shutil
import stat
import subprocess
import tempfile
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from html import escape
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import HTTPRedirectHandler, Request, build_opener

PUBLIC_URL = "https://substitutes.securityops.co"
PUBLIC_CHECK_URL = os.environ.get(
    "SECURITYOPS_PUBLIC_CHECK_URL", "https://ct116.example.invalid"
)
GUIX = "/var/guix/profiles/per-user/root/current-guix/bin/guix"
INBOX = Path("/var/lib/farm-site/inventory")
STORE_PATH = re.compile(r"^/gnu/store/([a-z0-9]{32})-([^/\s]+)$")
NAR_HASH = re.compile(r"^sha256:[a-z0-9]{52}$")
NAR_URL = re.compile(r"^nar/[A-Za-z0-9._+/-]+$")
CATALOG_PAGE = re.compile(
    r"^(?:pt-br/)?(?:system|home)(?:/page/(?:[2-9]|[1-9][0-9]+))?/index\.html$"
)
EXPLORE_ASSET = re.compile(
    r"^(?:pt-br/)?explore/index\.html$|^explore/(?:app\.js|data\.json)$"
)

catalog_spec = importlib.util.spec_from_file_location(
    "farm_catalog_site", Path(__file__).with_name("catalog.py")
)
if catalog_spec is None or catalog_spec.loader is None:
    raise RuntimeError("farm catalog validator is unavailable")
catalog = importlib.util.module_from_spec(catalog_spec)
catalog_spec.loader.exec_module(catalog)
render_spec = importlib.util.spec_from_file_location(
    "farm_render_site", Path(__file__).with_name("render.py")
)
if render_spec is None or render_spec.loader is None:
    raise RuntimeError("farm catalog renderer is unavailable")
render = importlib.util.module_from_spec(render_spec)
render_spec.loader.exec_module(render)
explore_spec = importlib.util.spec_from_file_location(
    "farm_explore_site", Path(__file__).with_name("explore.py")
)
if explore_spec is None or explore_spec.loader is None:
    raise RuntimeError("farm explorer is unavailable")
explore = importlib.util.module_from_spec(explore_spec)
explore_spec.loader.exec_module(explore)
SQL = """
SELECT e.id, e.timestamp, j.name, j.status,
       b.id, b.nix_name, b.status, COALESCE(b.starttime, 0),
       COALESCE(b.stoptime, 0), o.name, o.path
FROM (SELECT id, timestamp FROM evaluations
      WHERE specification = 'securityops' AND status = 0
      ORDER BY id DESC LIMIT 1) AS e
JOIN jobs j ON j.evaluation = e.id AND j.system = 'x86_64-linux'
JOIN builds b ON b.id = j.build
LEFT JOIN outputs o ON o.derivation = b.derivation AND o.name = 'out'
ORDER BY j.name
"""

COPY = {
    "en": {
        "lang": "en",
        "title": "SecurityOps Build Farm",
        "eyebrow": "Package status / Cuirass",
        "headline": "Build farm",
        "subtitle": "This map shows Channel jobs. The counters combine unique exact Channel, System, and Home targets; build history and public availability remain separate facts.",
        "partial_subtitle": "{sources} targets only. Other source inventories are in preparation; build history and public availability remain separate facts.",
        "channel_label": "Channel",
        "system_label": "System",
        "home_label": "Home",
        "pending_label": "Inventory in preparation",
        "skip": "Skip to packages",
        "language_nav": "Language",
        "available": "Public NAR routes",
        "building": "Building now",
        "stored": "Present on farm",
        "succeeded_count": "Builds succeeded",
        "issues": "Failed or blocked",
        "total": "Unique target outputs",
        "channel_jobs": "Channel jobs",
        "legend": "Status key",
        "published_label": "Public NAR route",
        "stored_label": "Present on CT126",
        "building_label": "Building",
        "not_published_label": "Not on farm",
        "map": "Package map",
        "eval": "Cuirass evaluation",
        "updated": "Snapshot generated",
        "source": "Substitute server",
        "explain": "Teal means the exact output has a matching public narinfo with a Signature field and a reachable NAR URL, not a full client-verified substitute. Cyan means it is valid in CT126's store but no public route was confirmed; it may have been built or imported. Yellow is an active build. Gray means the output is absent; the text gives the reason.",
        "scope_full": "The totals deduplicate Channel, System, and Home outputs by exact store path.",
        "scope_partial": "The totals include only the listed sources; pending inventories are excluded.",
        "success": "Build succeeded earlier · output absent from CT126",
        "success_public": "Build succeeded",
        "started": "Build in progress",
        "queued": "Queued",
        "scheduled": "Scheduled",
        "failed": "Build failed",
        "dependency": "Dependency failed",
        "other_failure": "Build failed (other)",
        "canceled": "Canceled",
        "unknown": "Status unknown",
        "details": "View public narinfo",
        "corresponding_source": "Corresponding source",
        "explore": "Interactive map",
        "footer": "Source: latest completed SecurityOps Cuirass evaluation. CT126 store validity, public narinfo and NAR reachability are checked every five minutes. Guix clients still verify the full NAR and signature.",
        "age_note": "If the evaluation time is over 24 hours old, this snapshot may no longer reflect current jobs.",
        "switch": "Português",
        "switch_href": "/pt-br/",
        "switch_lang": "pt-BR",
    },
    "pt-br": {
        "lang": "pt-BR",
        "title": "Build Farm SecurityOps",
        "eyebrow": "Estado dos pacotes / Cuirass",
        "headline": "Compilações",
        "subtitle": "Este mapa mostra os jobs do canal. Os indicadores combinam as saídas exatas e únicas de Canal, Sistema e Home; histórico de builds e disponibilidade pública são fatos distintos.",
        "partial_subtitle": "Somente alvos de {sources}. Os demais inventários estão em preparação; histórico de builds e disponibilidade pública são fatos distintos.",
        "channel_label": "Canal",
        "system_label": "Sistema",
        "home_label": "Home",
        "pending_label": "Inventário em preparação",
        "skip": "Ir para os pacotes",
        "language_nav": "Idioma",
        "available": "Rotas NAR públicas",
        "building": "Compilando agora",
        "stored": "Presentes na farm",
        "succeeded_count": "Compilações concluídas",
        "issues": "Falhas ou bloqueios",
        "total": "Saídas únicas",
        "channel_jobs": "Jobs do canal",
        "legend": "Legenda",
        "published_label": "Rota NAR pública",
        "stored_label": "Presente no CT126",
        "building_label": "Compilando",
        "not_published_label": "Ausente da farm",
        "map": "Mapa de pacotes",
        "eval": "Avaliação Cuirass",
        "updated": "Atualizado em",
        "source": "Servidor de substitutos",
        "explain": "Teal indica narinfo público da saída exata com campo Signature e URL NAR acessível, não um substituto validado integralmente pelo cliente. Ciano indica saída válida no store do CT126 sem rota pública confirmada; ela pode ter sido compilada ou importada. Amarelo indica build ativo. Cinza indica saída ausente; o texto explica o motivo.",
        "scope_full": "Os totais deduplicam Canal, Sistema e Home pelo caminho exato no store.",
        "scope_partial": "Os totais incluem apenas as origens listadas; inventários pendentes ficam de fora.",
        "success": "Compilação concluída antes · saída ausente no CT126",
        "success_public": "Compilação concluída",
        "started": "Compilação em andamento",
        "queued": "Na fila",
        "scheduled": "Agendado",
        "failed": "Compilação falhou",
        "dependency": "Dependência falhou",
        "other_failure": "Compilação falhou (outro)",
        "canceled": "Cancelado",
        "unknown": "Estado desconhecido",
        "details": "Ver narinfo público",
        "corresponding_source": "Código-fonte correspondente",
        "explore": "Mapa interativo",
        "footer": "Fonte: última avaliação SecurityOps concluída no Cuirass. A validade no CT126, o narinfo público e a rota NAR são verificados a cada cinco minutos. O cliente Guix ainda verifica o NAR completo e a assinatura.",
        "age_note": "Se a avaliação tiver mais de 24 horas, este snapshot pode não refletir os jobs atuais.",
        "switch": "English",
        "switch_href": "/",
        "switch_lang": "en",
    },
}

STATUS_LABEL = {
    -3: "queued",
    -2: "scheduled",
    -1: "started",
    0: "success",
    1: "failed",
    2: "dependency",
    3: "other_failure",
    4: "canceled",
}


def parse_snapshot_csv(value):
    """Parse one consistent completed evaluation exported by psql --csv."""
    packages = []
    seen_jobs = set()
    evaluation = timestamp = None
    for row in csv.reader(io.StringIO(value)):
        if len(row) != 11:
            raise ValueError(f"expected 11 snapshot columns, got {len(row)}")
        (
            row_eval,
            row_time,
            job,
            job_status,
            build_id,
            name,
            build_status,
            started,
            stopped,
            output,
            path,
        ) = row
        if not job or not name or not build_id:
            raise ValueError("incomplete Cuirass job")
        if job in seen_jobs:
            raise ValueError(f"duplicate Cuirass job: {job}")
        seen_jobs.add(job)
        row_eval, row_time = int(row_eval), int(row_time)
        if evaluation is None:
            evaluation, timestamp = row_eval, row_time
        elif (row_eval, row_time) != (evaluation, timestamp):
            raise ValueError("mixed Cuirass evaluations")
        if path and not STORE_PATH.fullmatch(path):
            raise ValueError(f"invalid store path for {job}")
        if output and output != "out":
            raise ValueError(f"unexpected output for {job}")
        packages.append(
            {
                "job": job,
                "name": name,
                "job_status": int(job_status),
                "build_status": int(build_status),
                "build_id": int(build_id),
                "started": int(started),
                "stopped": int(stopped),
                "path": path,
                "group": job.split(".", 1)[0],
            }
        )
    if not packages:
        raise ValueError("completed evaluation has no jobs")
    return {"evaluation": evaluation, "timestamp": timestamp, "packages": packages}


def validate_narinfo(store_path, document):
    """Reject a 200 response unless it advertises this exact output."""
    if not STORE_PATH.fullmatch(store_path):
        raise ValueError("invalid requested store path")
    fields = {}
    for line in document.splitlines():
        if not line.strip():
            continue
        key, separator, value = line.partition(": ")
        if not separator:
            raise ValueError("invalid narinfo field")
        fields.setdefault(key, []).append(value)
    if fields.get("StorePath") != [store_path]:
        raise ValueError("public narinfo describes another output")
    hashes = fields.get("NarHash", [])
    if len(hashes) != 1 or not NAR_HASH.fullmatch(hashes[0]):
        raise ValueError("public narinfo lacks a NAR hash")
    urls = fields.get("URL", [])
    if not urls or any(
        not NAR_URL.fullmatch(url)
        or any(segment in ("", ".", "..") for segment in url.split("/"))
        for url in urls
    ):
        raise ValueError("public narinfo has an invalid NAR URL")
    if not any(signature.strip() for signature in fields.get("Signature", [])):
        raise ValueError("public narinfo is unsigned")
    return True


class NoRedirects(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ValueError(f"unexpected substitute redirect: HTTP {code}")


def check_public_output(store_path, base_url=PUBLIC_URL):
    match = STORE_PATH.fullmatch(store_path)
    if not match:
        raise ValueError("invalid requested store path")
    request = Request(
        f"{base_url}/{match.group(1)}.narinfo",
        headers={"Accept": "text/plain", "User-Agent": "securityops-farm-site/1"},
    )
    opener = build_opener(NoRedirects())
    try:
        with opener.open(request, timeout=8) as response:
            if response.status != 200:
                raise ValueError(f"unexpected substitute status: {response.status}")
            data = response.read(65537)
            if len(data) > 65536:
                raise ValueError("public narinfo exceeds 64 KiB")
    except HTTPError as error:
        if error.code == 404:
            return False
        raise
    try:
        document = data.decode("utf-8")
        validate_narinfo(store_path, document)
    except ValueError as error:
        raise ValueError(f"{store_path}: {error}") from error
    nar_url = next(
        line.partition(": ")[2]
        for line in document.splitlines()
        if line.startswith("URL: ")
    )
    request = Request(
        f"{base_url}/{nar_url}",
        headers={"Range": "bytes=0-0", "User-Agent": "securityops-farm-site/1"},
    )
    try:
        with opener.open(request, timeout=30) as response:
            if response.status not in (200, 206) or not response.read(1):
                raise ValueError("advertised public NAR is unavailable")
    except HTTPError as error:
        if error.code == 404:
            return False
        raise
    return True


def published_outputs(snapshot, extra_paths=()):
    paths = sorted(
        {item["path"] for item in snapshot["packages"] if item["path"]}
        | set(extra_paths)
    )

    def probe(paths, base_url):
        found = []
        with ThreadPoolExecutor(max_workers=12) as pool:
            for start in range(0, len(paths), 48):
                batch = paths[start : start + 48]
                results = pool.map(
                    lambda path: check_public_output(path, base_url), batch
                )
                found.extend(path for path, public in zip(batch, results) if public)
        return found

    candidates = probe(paths, PUBLIC_CHECK_URL)
    return set(probe(candidates, PUBLIC_URL))


def read_manifest(inbox, source):
    """Read only a fixed accepted file; permit age solely for stale display."""
    if source not in ("system", "home"):
        raise ValueError("unknown inventory source")
    path = Path(inbox) / f"{source}.json"
    descriptor = os.open(path, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW)
    with os.fdopen(descriptor, "rb") as stream:
        if not stat.S_ISREG(os.fstat(stream.fileno()).st_mode):
            raise ValueError("inventory is not a regular file")
        payload = stream.read(catalog.MAX_MANIFEST_BYTES + 1)
    manifest = catalog.parse_manifest(
        payload, datetime.now(timezone.utc), allow_stale=True
    )
    if manifest["source"] != source:
        raise ValueError("inventory source does not match fixed filename")
    return manifest


def read_activity(inbox, manifest, now):
    """Show yellow only for fresh outputs in this accepted source inventory."""
    path = Path(inbox) / f"{manifest['source']}-activity.json"
    try:
        descriptor = os.open(path, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW)
    except FileNotFoundError:
        return {}
    with os.fdopen(descriptor, "rb") as stream:
        if not stat.S_ISREG(os.fstat(stream.fileno()).st_mode):
            raise ValueError("activity is not a regular file")
        activity = catalog.parse_activity(
            stream.read(catalog.MAX_MANIFEST_BYTES + 1), now
        )
    if activity["source"] != manifest["source"]:
        return {}
    updated = activity["updated_at"]
    generated = datetime.fromisoformat(manifest["generated_at"].replace("Z", "+00:00"))
    if now - updated > timedelta(minutes=15) or updated < generated:
        return {}
    known = {entry["path"] for entry in manifest["entries"]}
    if not set(activity["active_outputs"]) <= known:
        return {}
    return {path: updated for path in activity["active_outputs"]}


def valid_local_outputs(paths):
    """Ask the Guix daemon which exact store paths are valid in this CT."""
    requested = set(paths)
    if not requested:
        return set()
    if any(not STORE_PATH.fullmatch(path) for path in requested):
        raise ValueError("invalid store path in local availability probe")
    result = subprocess.run(
        [GUIX, "archive", "--missing"],
        input="\n".join(sorted(requested)) + "\n",
        capture_output=True,
        text=True,
        check=True,
        timeout=60,
    )
    missing = set(result.stdout.splitlines())
    if not missing <= requested:
        raise ValueError("Guix reported an unrequested missing store path")
    return requested - missing


def color_state(package, published, present):
    if published:
        return "available"
    if present:
        return "stored"
    if package["job_status"] == -1 or package["build_status"] == -1:
        return "building"
    return "unavailable"


def render_page(
    snapshot,
    published_paths,
    present_paths,
    language,
    generated_at,
    *,
    catalog_ready=False,
    catalog_sources=(),
    target_paths=None,
    active_paths=None,
):
    if language not in COPY:
        raise ValueError(f"unsupported language: {language}")
    copy = COPY[language]
    catalog_sources = set(catalog_sources)
    if not catalog_sources <= {"system", "home"}:
        raise ValueError("invalid catalog source")
    complete = catalog_sources == {"system", "home"}
    source_names = " + ".join(
        [copy["channel_label"]]
        + [
            copy[f"{source}_label"]
            for source in ("system", "home")
            if source in catalog_sources
        ]
    )
    subtitle = (
        copy["subtitle"]
        if complete
        else copy["partial_subtitle"].format(sources=source_names)
    )
    scope_note = copy["scope_full"] if complete else copy["scope_partial"]
    packages = snapshot["packages"]
    if not packages or any(not item["name"] for item in packages):
        raise ValueError("cannot render missing package names")
    successes = sum(item["job_status"] == 0 for item in packages)
    issues = sum(item["job_status"] in (1, 2, 3) for item in packages)
    targets = (
        {item["path"] for item in packages if item["path"]}
        if target_paths is None
        else set(target_paths)
    )
    active_paths = {} if active_paths is None else active_paths
    building_paths = {
        item["path"]
        for item in packages
        if item["path"]
        and color_state(
            item, item["path"] in published_paths, item["path"] in present_paths
        )
        == "building"
    } | {
        path
        for path in active_paths
        if path in targets and path not in published_paths and path not in present_paths
    }
    groups = defaultdict(list)
    for item in packages:
        groups[item["group"]].append(item)
    group_html = []
    for group, items in sorted(groups.items()):
        cards = []
        for item in items:
            public = item["path"] in published_paths
            state = color_state(item, public, item["path"] in present_paths)
            if state == "unavailable" and item["path"] in building_paths:
                state = "building"
            status = copy[STATUS_LABEL.get(item["job_status"], "unknown")]
            if state == "building":
                status = copy["started"]
            elif state in ("available", "stored"):
                if item["job_status"] == 0:
                    status = copy["success_public"]
                label = "published_label" if state == "available" else "stored_label"
                status = copy[label] + " · " + status
            link = ""
            if public:
                match = STORE_PATH.fullmatch(item["path"])
                if match is None:
                    raise ValueError("invalid published store path")
                store_hash = match.group(1)
                href = f"{PUBLIC_URL}/{store_hash}.narinfo"
                link = f'<a class="narinfo" href="{href}" rel="noopener noreferrer">{copy["details"]} ↗</a>'
                link += f' <a class="narinfo" href="/sources/">{copy["corresponding_source"]}</a>'
            cards.append(
                f'<article class="package {state}">'
                f'<span class="tile" aria-hidden="true"></span>'
                f'<div class="package-info"><h3>{escape(item["name"])}</h3>'
                f'<p class="job">{escape(item["job"])}</p>'
                f'<p class="status">{escape(status)}</p>{link}</div></article>'
            )
        group_html.append(
            f'<section class="group"><div class="group-heading"><h2>{escape(group)}</h2>'
            f'<span>{len(items):03d}</span></div><div class="package-grid">{"".join(cards)}</div></section>'
        )
    eval_time = datetime.fromtimestamp(snapshot["timestamp"], timezone.utc).strftime(
        "%Y-%m-%d %H:%M UTC"
    )
    summary = "".join(
        f'<div class="metric {state}"><dt class="label">{copy[label]}</dt><dd class="number">{count}</dd></div>'
        for state, count, label in (
            ("total", len(targets), "total"),
            ("successes", successes, "succeeded_count"),
            (
                "stored",
                len(targets & present_paths),
                "stored",
            ),
            ("available", len(targets & published_paths), "available"),
            ("building", len(building_paths), "building"),
            ("issues", issues, "issues"),
        )
    )
    legend = "".join(
        f'<li class="key {state}"><span class="swatch" aria-hidden="true"></span>{copy[label]}</li>'
        for state, label in (
            ("available", "published_label"),
            ("stored", "stored_label"),
            ("building", "building_label"),
            ("unavailable", "not_published_label"),
        )
    )
    source_nav = ""
    if catalog_ready:
        prefix = "/pt-br" if language == "pt-br" else ""
        links = [
            f'<nav class="source-nav" aria-label="{copy["map"]}">',
            f'<a href="{prefix}/" aria-current="page">{copy["channel_label"]}</a>',
        ]
        for source in ("system", "home"):
            label = copy[f"{source}_label"]
            if source in catalog_sources:
                links.append(f'<a href="{prefix}/{source}/">{label}</a>')
            else:
                links.append(
                    f'<span class="source-pending">{label} · {copy["pending_label"]}</span>'
                )
        links.append(f'<a href="{prefix}/explore/">{copy["explore"]}</a></nav>')
        source_nav = "".join(links)
    return f'''<!doctype html>
<html lang="{copy["lang"]}">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="dark">
  <meta name="description" content="{escape(subtitle)}">
  <title>{escape(copy["title"])}</title>
  <link rel="icon" href="data:,">
  <link rel="stylesheet" href="/style.css">
</head>
<body>
  <a class="skip-link" href="#packages">{copy["skip"]}</a>
  <div class="page-shell">
    <header class="topbar"><a class="brand" href="/" aria-label="SecurityOps Build Farm">SecurityOps<span class="brand-slash">/</span>Farm</a><nav aria-label="{copy["language_nav"]}"><a lang="{copy["switch_lang"]}" hreflang="{copy["switch_lang"]}" href="{copy["switch_href"]}">{copy["switch"]} <span aria-hidden="true">↗</span></a></nav></header>
    <main>
      {source_nav}
      <section class="hero" aria-labelledby="page-title"><p class="eyebrow">{copy["eyebrow"]}</p><h1 id="page-title" class="animated-title">{copy["headline"]}</h1><p class="hero-subtitle">{escape(subtitle)}</p><div class="hero-meta"><span>{copy["eval"]} <strong>#{snapshot["evaluation"]}</strong></span><span>{copy["channel_jobs"]} <strong>{len(packages)}</strong></span><span>{eval_time}</span></div><p class="freshness-note">{escape(copy["age_note"])}</p></section>
      <dl class="metrics" aria-label="{copy["map"]}">{summary}</dl>
      <section class="system-note" aria-labelledby="map-title"><div class="section-heading"><p class="section-index">SecurityOps / Cuirass</p><h2 id="map-title">{copy["map"]}</h2></div><p>{escape(copy["explain"])} {escape(scope_note)}</p><div class="legend" aria-label="{copy["legend"]}"><ul>{legend}</ul></div></section>
      <div id="packages" class="groups">{"".join(group_html)}</div>
    </main>
    <footer><div><span class="footer-mark">SECURITYOPS<span>.</span></span><p>{escape(copy["footer"])}</p></div><div class="footer-facts"><span>{copy["updated"]}<br><strong>{escape(generated_at)}</strong></span><span>{copy["source"]}<br><a href="{PUBLIC_URL}/" rel="noopener noreferrer">substitutes.securityops.co ↗</a></span></div></footer>
  </div>
</body>
</html>
'''


def fsync_directory(path):
    descriptor = os.open(
        path, os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW
    )
    try:
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def write_pages(
    snapshot,
    published_paths,
    root,
    generated_at,
    present_paths=None,
    extra_pages=None,
    target_paths=None,
    active_paths=None,
):
    """Publish both languages and CSS by switching one versioned symlink."""
    root = Path(root)
    present_paths = set() if present_paths is None else present_paths
    extra_pages = {} if extra_pages is None else extra_pages
    if any(
        not (CATALOG_PAGE.fullmatch(relative) or EXPLORE_ASSET.fullmatch(relative))
        or not isinstance(content, bytes)
        for relative, content in extra_pages.items()
    ):
        raise ValueError("invalid static catalog page")
    catalog_sources = {
        source
        for source in ("system", "home")
        if f"{source}/index.html" in extra_pages
        and f"pt-br/{source}/index.html" in extra_pages
    }
    files = {
        "index.html": render_page(
            snapshot,
            published_paths,
            present_paths,
            "en",
            generated_at,
            catalog_ready=bool(extra_pages),
            catalog_sources=catalog_sources,
            target_paths=target_paths,
            active_paths=active_paths,
        ).encode("utf-8"),
        "pt-br/index.html": render_page(
            snapshot,
            published_paths,
            present_paths,
            "pt-br",
            generated_at,
            catalog_ready=bool(extra_pages),
            catalog_sources=catalog_sources,
            target_paths=target_paths,
            active_paths=active_paths,
        ).encode("utf-8"),
        "style.css": Path(__file__).with_name("style.css").read_bytes(),
    }
    files.update(extra_pages)
    releases = root / "releases"
    releases.mkdir(parents=True, exist_ok=True)
    release = Path(tempfile.mkdtemp(prefix="snapshot-", dir=releases))
    release.chmod(0o755)
    link = root / f".current-{release.name}"
    try:
        content_directories = {release}
        for relative, contents in files.items():
            target = release / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            directory = target.parent
            while directory != release:
                content_directories.add(directory)
                directory = directory.parent
            with target.open("wb") as file:
                file.write(contents)
                file.flush()
                os.fchmod(file.fileno(), 0o644)
                os.fsync(file.fileno())
        for directory in sorted(
            content_directories, key=lambda path: len(path.parts), reverse=True
        ):
            fsync_directory(directory)
        fsync_directory(releases)
        os.symlink(f"releases/{release.name}", link, target_is_directory=True)
        os.replace(link, root / "current")
        fsync_directory(root)
    finally:
        link.unlink(missing_ok=True)

    current = (root / "current").resolve()
    old_releases = sorted(
        (
            path
            for path in releases.iterdir()
            if path.is_dir()
            and not path.is_symlink()
            and path.name.startswith("snapshot-")
        ),
        key=lambda path: path.stat().st_mtime,
        reverse=True,
    )
    for old in old_releases[12:]:
        if old != current:
            try:
                shutil.rmtree(old)
            except OSError as error:
                print(f"warning: could not prune {old}: {error}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    result = subprocess.run(
        ["psql", "-X", "--csv", "--tuples-only", "-d", "cuirass", "-c", SQL],
        capture_output=True,
        text=True,
        check=True,
        timeout=30,
    )
    snapshot = parse_snapshot_csv(result.stdout)
    manifests = []
    for source in ("system", "home"):
        try:
            manifests.append(read_manifest(INBOX, source))
        except FileNotFoundError:
            pass
    pending_sources = {"system", "home"} - {item["source"] for item in manifests}
    targets = catalog.merge_targets(manifests, snapshot["packages"])
    paths = [target["path"] for target in targets]
    published = published_outputs(snapshot, extra_paths=paths)
    present = valid_local_outputs(paths)
    now = datetime.now(timezone.utc)
    active = {}
    for manifest in manifests:
        active.update(read_activity(INBOX, manifest, now))
    active_channel_paths = {
        item["path"]
        for item in snapshot["packages"]
        if item["path"] and (item["job_status"] == -1 or item["build_status"] == -1)
    }
    active.update({path: now for path in active_channel_paths})
    generated_at = now.strftime("%Y-%m-%d %H:%M UTC")
    extra_pages = {}
    for manifest in manifests:
        for language in ("en", "pt-br"):
            extra_pages.update(
                render.render_source_pages(
                    manifest,
                    targets,
                    published,
                    present,
                    active,
                    now,
                    language,
                    generated_at,
                )
            )
    stale_sources = {
        manifest["source"]
        for manifest in manifests
        if now - datetime.fromisoformat(manifest["heartbeat_at"].replace("Z", "+00:00"))
        > timedelta(hours=24)
    }
    if now - datetime.fromtimestamp(snapshot["timestamp"], timezone.utc) > timedelta(
        hours=24
    ):
        stale_sources.add("channel")
    source_times = {
        manifest["source"]: datetime.fromisoformat(
            manifest["heartbeat_at"].replace("Z", "+00:00")
        )
        for manifest in manifests
    }
    source_times["channel"] = datetime.fromtimestamp(
        snapshot["timestamp"], timezone.utc
    )
    extra_pages.update(
        explore.build_assets(
            targets,
            published,
            present,
            active,
            now,
            active_channel_paths,
            stale_sources=stale_sources,
            source_times=source_times,
            pending_sources=pending_sources,
        )
    )
    write_pages(
        snapshot,
        published,
        args.output_dir,
        generated_at,
        present_paths=present,
        extra_pages=extra_pages,
        target_paths=paths,
        active_paths=active,
    )
    print(
        f"evaluation={snapshot['evaluation']} jobs={len(snapshot['packages'])} succeeded={sum(item['job_status'] == 0 for item in snapshot['packages'])} targets={len(targets)} present={len(present)} published={len(published)} updated={generated_at}"
    )


if __name__ == "__main__":
    main()
