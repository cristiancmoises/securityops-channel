"""Generate the bounded, opt-in membership map from validated farm targets."""

import importlib.util
import json
from datetime import datetime
from html import escape
from pathlib import Path

catalog_spec = importlib.util.spec_from_file_location(
    "farm_catalog_explore", Path(__file__).with_name("catalog.py")
)
if catalog_spec is None or catalog_spec.loader is None:
    raise RuntimeError("farm catalog validator is unavailable")
catalog = importlib.util.module_from_spec(catalog_spec)
catalog_spec.loader.exec_module(catalog)

SOURCES = ("channel", "system", "home")
COPY = {
    "en": {
        "lang": "en",
        "title": "Explore packages",
        "nav": "Farm views",
        "clean": "Clean view",
        "interactive": "Interactive map",
        "heading": "Membership map",
        "intro": "Explore exact package outputs by source and availability. This is not a dependency graph: the farm inventory does not yet contain dependency edges.",
        "source": "Source",
        "channel": "Channel",
        "system": "System",
        "home": "Home",
        "search": "Search packages",
        "status": "Availability",
        "all": "All states",
        "public": "Public NAR route",
        "stored": "Present on CT126",
        "building": "Building",
        "unavailable": "Unavailable",
        "zoom_in": "Zoom in",
        "zoom_out": "Zoom out",
        "reset": "Reset zoom",
        "map": "Package membership map",
        "results": "Matching packages",
        "details": "Selected package",
        "enable": "Enable JavaScript to use this optional map. The clean catalog remains fully available.",
        "fallback": "The default catalog is available without JavaScript.",
        "stale": "This source inventory is over 24 hours old. Its targets may no longer match the current configuration.",
        "switch": "Português",
        "switch_href": "/pt-br/explore/",
    },
    "pt-br": {
        "lang": "pt-BR",
        "title": "Explorar pacotes",
        "nav": "Visões da farm",
        "clean": "Visão limpa",
        "interactive": "Mapa interativo",
        "heading": "Mapa de pertencimento",
        "intro": "Explore saídas exatas de pacotes por origem e disponibilidade. Isto não é um grafo de dependências: o inventário da farm ainda não contém essas ligações.",
        "source": "Origem",
        "channel": "Canal",
        "system": "Sistema",
        "home": "Home",
        "search": "Buscar pacotes",
        "status": "Disponibilidade",
        "all": "Todos os estados",
        "public": "Rota NAR pública",
        "stored": "Presente no CT126",
        "building": "Compilando",
        "unavailable": "Indisponível",
        "zoom_in": "Aproximar",
        "zoom_out": "Afastar",
        "reset": "Restaurar zoom",
        "map": "Mapa de pacotes por origem",
        "results": "Pacotes encontrados",
        "details": "Pacote selecionado",
        "enable": "Ative o JavaScript para usar este mapa opcional. O catálogo limpo continua disponível.",
        "fallback": "O catálogo padrão funciona sem JavaScript.",
        "stale": "Este inventário tem mais de 24 horas. Os alvos podem não corresponder mais à configuração atual.",
        "switch": "English",
        "switch_href": "/explore/",
    },
}


def build_payload(
    source,
    targets,
    published_paths,
    present_paths,
    active_paths,
    now,
    *,
    active_channel_paths,
    inventory_stale=False,
    inventory_pending=False,
    source_at=None,
):
    """Keep all recognized package targets; the browser bounds visible nodes."""
    if (
        source not in SOURCES
        or not isinstance(now, datetime)
        or now.tzinfo is None
        or type(inventory_stale) is not bool
        or type(inventory_pending) is not bool
        or (
            source_at is not None
            and (not isinstance(source_at, datetime) or source_at.tzinfo is None)
        )
    ):
        raise ValueError("invalid map source or snapshot time")
    nodes = []
    other_outputs = 0
    for target in sorted(targets, key=lambda item: item["path"]):
        members = [
            member for member in target["memberships"] if member["source"] == source
        ]
        if not members:
            continue
        if not any(member["kind"] == "package" for member in members):
            other_outputs += 1
            continue
        path = target["path"]
        catalog._path(path)
        member = next(member for member in members if member["kind"] == "package")
        name = member["name"]
        version = member["version"]
        if (
            not isinstance(name, str)
            or len(name) > 256
            or not catalog.TEXT.fullmatch(name)
            or not isinstance(version, str)
            or len(version) > 256
            or (version and not catalog.TEXT.fullmatch(version))
        ):
            raise ValueError("invalid package label in map")
        state = catalog.target_state(
            target, published_paths, present_paths, active_paths, now
        )
        if state == "unavailable" and path in active_channel_paths:
            state = "building"
        nodes.append(
            {
                "id": len(nodes) + 1,
                "name": name,
                "version": version,
                "path": path,
                "status": state,
                "direct": any(member["direct"] for member in members),
                "sources": sorted({item["source"] for item in target["memberships"]}),
            }
        )
    if inventory_pending and (nodes or other_outputs):
        raise ValueError("pending inventory cannot contain targets")
    return {
        "schema": 1,
        "source": source,
        "generated_at": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "source_at": (source_at or now).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "total": len(nodes),
        "other_outputs": other_outputs,
        "inventory_stale": inventory_stale,
        "inventory_pending": inventory_pending,
        "nodes": nodes,
    }


def render_page(language):
    if language not in COPY:
        raise ValueError("unknown map language")
    copy = COPY[language]
    clean = "/pt-br/" if language == "pt-br" else "/"
    map_url = "/pt-br/explore/" if language == "pt-br" else "/explore/"
    options = "".join(
        f'<option value="{value}">{escape(copy[label])}</option>'
        for value, label in (
            ("all", "all"),
            ("available", "public"),
            ("stored", "stored"),
            ("building", "building"),
            ("unavailable", "unavailable"),
        )
    )
    return f'''<!doctype html>
<html lang="{copy["lang"]}">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="dark">
  <meta name="description" content="{escape(copy["intro"])}">
  <title>{escape(copy["title"])} · SecurityOps Build Farm</title>
  <link rel="icon" href="data:,">
  <link rel="stylesheet" href="/style.css">
  <script src="/explore/app.js" defer></script>
</head>
<body data-language="{language}">
  <a class="skip-link" href="#results">{escape(copy["results"])}</a>
  <div class="page-shell">
    <header class="topbar"><a class="brand" href="{clean}">SecurityOps<span class="brand-slash">/</span>Farm</a><a href="{copy["switch_href"]}" hreflang="{COPY["pt-br" if language == "en" else "en"]["lang"]}">{escape(copy["switch"])}</a></header>
    <main>
      <nav class="source-nav" aria-label="{escape(copy["nav"])}"><a href="{clean}">{escape(copy["clean"])}</a><a href="{map_url}" aria-current="page">{escape(copy["interactive"])}</a></nav>
      <section class="hero explore-hero"><p class="eyebrow">SecurityOps / Guix</p><h1 class="animated-title">{escape(copy["heading"])}</h1><p class="hero-subtitle">{escape(copy["intro"])}</p></section>
      <noscript><p class="stale-warning">{escape(copy["enable"])}</p></noscript>
      <p id="inventory-warning" class="stale-warning" role="status" hidden>{escape(copy["stale"])}</p>
      <section class="explore-workspace" aria-label="{escape(copy["map"])}">
        <div class="explore-controls">
          <label>{escape(copy["source"])}<select id="source"><option value="channel">{escape(copy["channel"])}</option><option value="system">{escape(copy["system"])}</option><option value="home">{escape(copy["home"])}</option></select></label>
          <label>{escape(copy["search"])}<input id="search" type="search" autocomplete="off" maxlength="200"></label>
          <label>{escape(copy["status"])}<select id="status">{options}</select></label>
        </div>
        <div class="explore-toolbar"><p id="count" role="status" aria-live="polite">{escape(copy["enable"])}</p><div><button id="zoom-out" type="button" aria-label="{escape(copy["zoom_out"])}">−</button><button id="zoom-reset" type="button" aria-label="{escape(copy["reset"])}">100%</button><button id="zoom-in" type="button" aria-label="{escape(copy["zoom_in"])}">+</button></div></div>
        <svg id="map" viewBox="0 0 1000 700" role="img" aria-label="{escape(copy["map"])}"></svg>
        <div class="explore-bottom"><section id="results"><h2>{escape(copy["results"])}</h2><ol id="result-list"></ol></section><aside aria-labelledby="selected-heading"><h2 id="selected-heading">{escape(copy["details"])}</h2><p id="selected" aria-live="polite">—</p></aside></div>
      </section>
    </main>
    <footer><p>{escape(copy["fallback"])} <a href="{clean}">{escape(copy["clean"])}</a></p></footer>
  </div>
</body>
</html>
'''


def build_assets(
    targets,
    published_paths,
    present_paths,
    active_paths,
    now,
    active_channel_paths,
    *,
    stale_sources=(),
    source_times=None,
    pending_sources=(),
):
    files = {
        "explore/index.html": render_page("en").encode("utf-8"),
        "pt-br/explore/index.html": render_page("pt-br").encode("utf-8"),
        "explore/app.js": Path(__file__).with_name("explore-app.js").read_bytes(),
    }
    source_times = {} if source_times is None else source_times
    pending_sources = set(pending_sources)
    if not pending_sources <= {"system", "home"}:
        raise ValueError("invalid pending inventory source")
    snapshot = {"schema": 1, "sources": {}}
    for source in SOURCES:
        snapshot["sources"][source] = build_payload(
            source,
            targets,
            published_paths,
            present_paths,
            active_paths,
            now,
            active_channel_paths=active_channel_paths,
            inventory_stale=source in stale_sources,
            inventory_pending=source in pending_sources,
            source_at=source_times.get(source, now),
        )
    files["explore/data.json"] = json.dumps(
        snapshot, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")
    return files
