"use strict";

(() => {
  const svgNS = "http://www.w3.org/2000/svg";
  const sources = new Set(["channel", "system", "home"]);
  const states = new Set(["available", "stored", "building", "unavailable"]);
  const storePath = /^\/gnu\/store\/[a-z0-9]{32}-[_A-Za-z0-9][_A-Za-z0-9+.?~-]*$/;
  const language = document.body.dataset.language === "pt-br" ? "pt-br" : "en";
  const words = {
    en: {
      shown: "shown", of: "of", matches: "matching packages", omitted: "on the map; narrow your search to see the rest",
      none: "No packages match these filters.", error: "The map data could not be loaded. Use the clean catalog.",
      available: "Public NAR route", stored: "Present on CT126", building: "Building", unavailable: "Unavailable",
      direct: "Direct package", dependency: "Dependency", public: "View public narinfo",
      sources: "Also in", other: "Unclassified closure outputs remain in the clean catalog",
      stale: "This source inventory is over 24 hours old. Its targets may no longer match the current configuration.",
      pending: "Inventory in preparation",
    },
    "pt-br": {
      shown: "visíveis", of: "de", matches: "pacotes encontrados", omitted: "no mapa; refine a busca para ver o restante",
      none: "Nenhum pacote corresponde aos filtros.", error: "Os dados do mapa não puderam ser carregados. Use o catálogo limpo.",
      available: "Rota NAR pública", stored: "Presente no CT126", building: "Compilando", unavailable: "Indisponível",
      direct: "Pacote direto", dependency: "Dependência", public: "Ver narinfo público",
      sources: "Também em", other: "Saídas não classificadas da closure continuam no catálogo limpo",
      stale: "Este inventário tem mais de 24 horas. Os alvos podem não corresponder mais à configuração atual.",
      pending: "Inventário em preparação",
    },
  }[language];
  const sourceControl = document.getElementById("source");
  const searchControl = document.getElementById("search");
  const statusControl = document.getElementById("status");
  const map = document.getElementById("map");
  const count = document.getElementById("count");
  const list = document.getElementById("result-list");
  const selected = document.getElementById("selected");
  const warning = document.getElementById("inventory-warning");
  let snapshot = null;
  let payload = null;
  let zoom = 1;

  function validate(data, source) {
    if (!data || data.schema !== 1 || data.source !== source || !Array.isArray(data.nodes) ||
        data.nodes.length > 50000 || data.total !== data.nodes.length ||
        typeof data.inventory_stale !== "boolean" ||
        typeof data.inventory_pending !== "boolean" ||
        (data.inventory_pending && (data.nodes.length !== 0 || data.other_outputs !== 0)) ||
        typeof data.source_at !== "string" ||
        !/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$/.test(data.source_at) ||
        !Number.isFinite(Date.parse(data.source_at))) {
      throw new Error("invalid map document");
    }
    for (const node of data.nodes) {
      if (!Number.isSafeInteger(node.id) || node.id < 1 || !storePath.test(node.path) ||
          !states.has(node.status) || typeof node.name !== "string" ||
          typeof node.version !== "string" || typeof node.direct !== "boolean" ||
          !Array.isArray(node.sources) || node.sources.some((value) => !sources.has(value))) {
        throw new Error("invalid map node");
      }
    }
    return data;
  }

  function element(name, attrs = {}) {
    const node = document.createElementNS(svgNS, name);
    for (const [key, value] of Object.entries(attrs)) node.setAttribute(key, String(value));
    return node;
  }

  function select(node) {
    selected.replaceChildren();
    const name = document.createElement("strong");
    name.textContent = node.name + (node.version ? "-" + node.version : "");
    const state = document.createElement("span");
    state.className = "explore-detail-state " + node.status;
    state.textContent = words[node.status] + " · " + (node.direct ? words.direct : words.dependency);
    const path = document.createElement("code");
    path.textContent = node.path;
    const membership = document.createElement("span");
    membership.textContent = words.sources + ": " + node.sources.join(" · ");
    selected.append(name, state, path, membership);
    if (node.status === "available") {
      const link = document.createElement("a");
      link.href = "https://substitutes.securityops.co/" + node.path.slice(11, 43) + ".narinfo";
      link.rel = "noopener noreferrer";
      link.textContent = words.public + " ↗";
      selected.append(link);
    }
  }

  function position(index) {
    let remaining = index;
    for (let ring = 1; ring <= 5; ring++) {
      const capacity = ring * 16;
      if (remaining < capacity) {
        const angle = 2 * Math.PI * remaining / capacity - Math.PI / 2;
        const radius = 62 + ring * 50;
        return [500 + Math.cos(angle) * radius, 350 + Math.sin(angle) * radius];
      }
      remaining -= capacity;
    }
    return [500, 350];
  }

  function render() {
    if (!payload) return;
    map.replaceChildren();
    list.replaceChildren();
    selected.textContent = "—";
    if (payload.inventory_pending) {
      count.textContent = words.pending;
      const pending = document.createElement("li");
      pending.textContent = words.pending;
      list.append(pending);
      return;
    }
    const query = searchControl.value.trim().toLocaleLowerCase();
    const filter = statusControl.value;
    const matched = payload.nodes.filter((node) =>
      (filter === "all" || node.status === filter) &&
      (node.name + " " + node.version + " " + node.path).toLocaleLowerCase().includes(query));
    const visible = matched.slice(0, 200);
    const overflow = matched.length > visible.length;
    count.textContent = `${visible.length} ${words.shown} ${words.of} ${matched.length} ${words.matches}` +
      (overflow ? ` ${words.omitted}.` : ".") +
      (payload.other_outputs ? ` ${payload.other_outputs} ${words.other}.` : "");
    if (!visible.length) {
      const empty = document.createElement("li");
      empty.textContent = words.none;
      list.append(empty);
      return;
    }
    const edges = element("g", {class: "map-edges"});
    const nodes = element("g", {class: "map-nodes"});
    const center = element("circle", {cx: 500, cy: 350, r: 27, class: "map-hub"});
    nodes.append(center);
    const centerLabel = element("text", {x: 500, y: 355, "text-anchor": "middle", class: "map-hub-label"});
    centerLabel.textContent = sourceControl.selectedOptions[0].textContent;
    nodes.append(centerLabel);
    visible.forEach((node, index) => {
      const [x, y] = position(index);
      edges.append(element("line", {x1: 500, y1: 350, x2: x, y2: y}));
      const shape = element(node.direct ? "rect" : "circle", node.direct
        ? {x: x - 7, y: y - 7, width: 14, height: 14, class: "map-node " + node.status}
        : {cx: x, cy: y, r: 7, class: "map-node " + node.status});
      const group = element("g", {class: "map-point"});
      const title = element("title");
      title.textContent = `${node.name}-${node.version} · ${words[node.status]}`;
      group.append(shape, title);
      group.addEventListener("click", () => select(node));
      nodes.append(group);
      const item = document.createElement("li");
      const button = document.createElement("button");
      button.type = "button";
      button.className = "explore-result " + node.status;
      button.textContent = node.name + (node.version ? "-" + node.version : "") + " · " + words[node.status];
      button.addEventListener("click", () => select(node));
      item.append(button);
      list.append(item);
    });
    map.append(edges, nodes);
  }

  function chooseSource() {
    if (!snapshot || !sources.has(sourceControl.value)) return;
    payload = snapshot.sources[sourceControl.value];
    updateStaleWarning();
    render();
  }

  function updateStaleWarning() {
    if (!payload) return;
    if (payload.inventory_pending) {
      warning.hidden = true;
      warning.textContent = "";
      return;
    }
    const sourceAge = Date.now() - Date.parse(payload.source_at);
    const stale = payload.inventory_stale || sourceAge > 24 * 60 * 60 * 1000 || sourceAge < -5 * 60 * 1000;
    warning.hidden = !stale;
    warning.textContent = stale ? words.stale : "";
  }

  async function load() {
    count.textContent = "…";
    try {
      const response = await fetch("/explore/data.json", {credentials: "omit", cache: "no-store"});
      if (!response.ok) throw new Error("map HTTP status " + response.status);
      const data = await response.json();
      if (!data || data.schema !== 1 || !data.sources ||
          Object.keys(data.sources).length !== sources.size) throw new Error("invalid map snapshot");
      for (const source of sources) validate(data.sources[source], source);
      snapshot = data;
      chooseSource();
    } catch (error) {
      payload = null;
      warning.hidden = true;
      map.replaceChildren();
      list.replaceChildren();
      selected.textContent = "—";
      count.textContent = words.error;
      console.error("farm map load failed", error);
    }
  }

  function setZoom(value) {
    zoom = Math.max(0.8, Math.min(2.2, value));
    const width = 1000 / zoom;
    const height = 700 / zoom;
    map.setAttribute("viewBox", `${500 - width / 2} ${350 - height / 2} ${width} ${height}`);
    document.getElementById("zoom-reset").textContent = Math.round(zoom * 100) + "%";
  }

  sourceControl.addEventListener("change", chooseSource);
  searchControl.addEventListener("input", render);
  statusControl.addEventListener("change", render);
  document.getElementById("zoom-in").addEventListener("click", () => setZoom(zoom + 0.2));
  document.getElementById("zoom-out").addEventListener("click", () => setZoom(zoom - 0.2));
  document.getElementById("zoom-reset").addEventListener("click", () => setZoom(1));
  setInterval(updateStaleWarning, 60 * 1000);
  load();
})();
