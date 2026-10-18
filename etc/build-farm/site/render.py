"""Render sanitized System/Home inventories as paginated static HTML."""

import importlib.util
from datetime import datetime, timedelta, timezone
from html import escape
from pathlib import Path

catalog_spec = importlib.util.spec_from_file_location(
    "farm_catalog_render", Path(__file__).with_name("catalog.py")
)
if catalog_spec is None or catalog_spec.loader is None:
    raise RuntimeError("farm catalog is unavailable")
catalog = importlib.util.module_from_spec(catalog_spec)
catalog_spec.loader.exec_module(catalog)

COPY = {
    "en": {
        "lang": "en",
        "nav": "Farm views",
        "channel": "Channel",
        "system": "System",
        "home": "Home",
        "explore": "Interactive map",
        "subtitle": "Exact outputs required by this Guix configuration. Presence on CT126 and public distribution are independent.",
        "skip": "Skip to outputs",
        "direct_section": "Direct packages",
        "closure_section": "Closure dependencies and outputs",
        "direct": "Direct package",
        "dependency": "Dependency",
        "other": "Closure output",
        "tracked": "Exact outputs",
        "direct_count": "Direct packages",
        "stored_count": "Present on CT126",
        "public_count": "Public NAR routes",
        "building_count": "Building now",
        "available": "Public NAR route",
        "stored": "Present on CT126",
        "building": "Build in progress",
        "unavailable": "Not present on CT126",
        "stale": "Inventory stale — laptop heartbeat is over 24 hours old. Availability was checked now, but this target list may have changed.",
        "age_note": "If this heartbeat is over 24 hours old, this target list may no longer match the laptop configuration.",
        "generated": "Inventory generated",
        "heartbeat": "Laptop heartbeat",
        "snapshot": "Availability checked",
        "page": "Page",
        "previous": "Previous page",
        "next": "Next page",
        "pages": "Catalog pages",
        "identity": "Exact store identity",
        "sources": "Also in",
    },
    "pt-br": {
        "lang": "pt-BR",
        "nav": "Visões da farm",
        "channel": "Canal",
        "system": "Sistema",
        "home": "Home",
        "explore": "Mapa interativo",
        "subtitle": "Saídas exatas necessárias para esta configuração Guix. Presença no CT126 e distribuição pública são fatos independentes.",
        "skip": "Ir para as saídas",
        "direct_section": "Pacotes diretos",
        "closure_section": "Dependências e outras saídas da closure",
        "direct": "Pacote direto",
        "dependency": "Dependência",
        "other": "Saída da closure",
        "tracked": "Saídas exatas",
        "direct_count": "Pacotes diretos",
        "stored_count": "Presentes no CT126",
        "public_count": "Rotas NAR públicas",
        "building_count": "Compilando agora",
        "available": "Rota NAR pública",
        "stored": "Presente no CT126",
        "building": "Compilação em andamento",
        "unavailable": "Ausente do CT126",
        "stale": "Inventário desatualizado — o laptop não envia confirmação há mais de 24 horas. A disponibilidade foi verificada agora, mas os alvos podem ter mudado.",
        "age_note": "Se esta confirmação tiver mais de 24 horas, esta lista de alvos pode não corresponder à configuração atual do laptop.",
        "generated": "Inventário gerado",
        "heartbeat": "Confirmação do laptop",
        "snapshot": "Disponibilidade verificada",
        "page": "Página",
        "previous": "Página anterior",
        "next": "Próxima página",
        "pages": "Páginas do catálogo",
        "identity": "Identidade exata no store",
        "sources": "Também em",
    },
}


def page_url(source, language, page):
    prefix = "/pt-br" if language == "pt-br" else ""
    base = f"{prefix}/{source}/"
    return base if page == 1 else f"{base}page/{page}/"


def _card(entry, target, public, present, active, now, copy):
    path = entry["path"]
    state = catalog.target_state(target, public, present, active, now)
    scope = copy["direct"] if entry["direct"] else copy["dependency"]
    if entry["kind"] == "output":
        scope = copy["other"]
    memberships = target.get("memberships", [])
    sources = sorted({item["source"] for item in memberships})
    badges = "".join(
        f'<span class="source-badge">{escape(copy[source])}</span>'
        for source in sources
    )
    name = entry["name"] + (f"-{entry['version']}" if entry["version"] else "")
    return (
        f'<article class="package {state}"><span class="tile" aria-hidden="true"></span>'
        f'<div class="package-info"><h3>{escape(name)}</h3>'
        f'<p class="job">{escape(scope)} · {escape(entry["output"])}</p>'
        f'<p class="status">{escape(copy[state])}</p>'
        f'<p class="store-label">{escape(copy["identity"])}</p>'
        f'<code class="store-path">{escape(path)}</code>'
        f'<div class="source-badges" aria-label="{escape(copy["sources"])}">{badges}</div></div></article>'
    )


def render_source_pages(
    manifest,
    targets,
    published_paths,
    present_paths,
    active_paths,
    now,
    language,
    generated_at,
    *,
    page_size=120,
):
    """Return relative HTML files for one validated source, including all entries."""
    if language not in COPY or manifest["source"] not in ("system", "home"):
        raise ValueError("unknown catalog language or source")
    if page_size < 1 or page_size > 500:
        raise ValueError("invalid static catalog page size")
    if now.tzinfo is None:
        raise ValueError("snapshot time must include a timezone")
    copy = COPY[language]
    source = manifest["source"]
    by_path = {target["path"]: target for target in targets}
    entries = sorted(
        manifest["entries"],
        key=lambda item: (
            not item["direct"],
            item["name"],
            item["version"],
            item["path"],
        ),
    )
    if not entries or any(entry["path"] not in by_path for entry in entries):
        raise ValueError("catalog target missing from exact-path merge")
    heartbeat = datetime.strptime(
        manifest["heartbeat_at"], "%Y-%m-%dT%H:%M:%SZ"
    ).replace(tzinfo=timezone.utc)
    stale = now - heartbeat > timedelta(hours=24)
    total_pages = (len(entries) + page_size - 1) // page_size
    direct_count = sum(item["direct"] and item["kind"] == "package" for item in entries)
    metrics = (
        ("total", copy["tracked"], len(entries)),
        ("successes", copy["direct_count"], direct_count),
        (
            "stored",
            copy["stored_count"],
            sum(item["path"] in present_paths for item in entries),
        ),
        (
            "available",
            copy["public_count"],
            sum(item["path"] in published_paths for item in entries),
        ),
        (
            "building",
            copy["building_count"],
            sum(
                catalog.target_state(
                    by_path[item["path"]],
                    published_paths,
                    present_paths,
                    active_paths,
                    now,
                )
                == "building"
                for item in entries
            ),
        ),
    )
    summary = "".join(
        f'<div class="metric {state}"><dt class="label">{escape(label)}</dt><dd class="number">{count}</dd></div>'
        for state, label, count in metrics
    )
    prefix = "pt-br/" if language == "pt-br" else ""
    channel_url = "/pt-br/" if language == "pt-br" else "/"
    nav = (
        f'<nav class="source-nav" aria-label="{escape(copy["nav"])}">'
        f'<a href="{channel_url}">{escape(copy["channel"])}</a>'
        f'<a href="{page_url("system", language, 1)}">{escape(copy["system"])}</a>'
        f'<a href="{page_url("home", language, 1)}">{escape(copy["home"])}</a>'
        f'<a href="{"/pt-br" if language == "pt-br" else ""}/explore/">{escape(copy["explore"])}</a></nav>'
    )
    pages = {}
    for page in range(1, total_pages + 1):
        portion = entries[(page - 1) * page_size : page * page_size]
        groups = []
        for direct, heading in ((True, "direct_section"), (False, "closure_section")):
            group_entries = [item for item in portion if item["direct"] is direct]
            if not group_entries:
                continue
            cards = []
            for entry in group_entries:
                target = by_path[entry["path"]]
                cards.append(
                    _card(
                        entry,
                        target,
                        published_paths,
                        present_paths,
                        active_paths,
                        now,
                        copy,
                    )
                )
            groups.append(
                f'<section class="group"><div class="group-heading"><h2>{escape(copy[heading])}</h2>'
                f'<span>{len(group_entries):03d}</span></div><div class="package-grid">{"".join(cards)}</div></section>'
            )
        previous = (
            f'<a href="{page_url(source, language, page - 1)}">{escape(copy["previous"])}</a>'
            if page > 1
            else ""
        )
        following = (
            f'<a href="{page_url(source, language, page + 1)}">{escape(copy["next"])}</a>'
            if page < total_pages
            else ""
        )
        page_nav = (
            f'<nav class="pagination" aria-label="{escape(copy["pages"])}">{previous}'
            f"<span>{escape(copy['page'])} {page}/{total_pages}</span>{following}</nav>"
        )
        other_language = "pt-br" if language == "en" else "en"
        language_link = page_url(source, other_language, page)
        stale_note = (
            f'<p class="stale-warning" role="status">{escape(copy["stale"])}</p>'
            if stale
            else ""
        )
        html = f'''<!doctype html>
<html lang="{copy["lang"]}">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="dark">
  <meta name="description" content="{escape(copy["subtitle"])}">
  <title>{escape(copy[source])} · SecurityOps Build Farm</title>
  <link rel="icon" href="data:,">
  <link rel="stylesheet" href="/style.css">
</head>
<body>
  <a class="skip-link" href="#outputs">{escape(copy["skip"])}</a>
  <div class="page-shell">
    <header class="topbar"><a class="brand" href="{channel_url}">SecurityOps<span class="brand-slash">/</span>Farm</a><a href="{language_link}" hreflang="{COPY[other_language]["lang"]}">{COPY[other_language][source]}</a></header>
    <main>
      {nav}
      <section class="hero"><p class="eyebrow">{escape(copy["nav"])} / {escape(copy[source])}</p><h1 class="animated-title">{escape(copy[source])}</h1><p class="hero-subtitle">{escape(copy["subtitle"])}</p><div class="hero-meta"><span>{escape(copy["generated"])} <strong>{escape(manifest["generated_at"])}</strong></span><span>{escape(copy["heartbeat"])} <strong>{escape(manifest["heartbeat_at"])}</strong></span></div><p class="freshness-note">{escape(copy["age_note"])}</p>{stale_note}</section>
      <dl class="metrics">{summary}</dl>
      <div id="outputs" class="groups">{"".join(groups)}</div>
      {page_nav}
    </main>
    <footer><p>{escape(copy["snapshot"])}: {escape(generated_at)}. {escape(copy["identity"])}: {escape(manifest["root_drv"])}</p></footer>
  </div>
</body>
</html>
'''
        relative = (
            f"{prefix}{source}/index.html"
            if page == 1
            else f"{prefix}{source}/page/{page}/index.html"
        )
        pages[relative] = html.encode("utf-8")
    return pages
