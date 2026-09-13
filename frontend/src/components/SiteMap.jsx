import { useMemo, useState } from "react";
import {
  ConnectionMode,
  Controls,
  MarkerType,
  MiniMap,
  ReactFlow,
} from "@xyflow/react";
import "@xyflow/react/dist/style.css";
import { MapDeviceNode } from "./nodes.jsx";
import TopoEdge, { edgeChipText } from "./TopoEdge.jsx";

const NODE_TYPES = { mapDevice: MapDeviceNode };
const EDGE_TYPES = { topo: TopoEdge };

const NODE_W = 220;
const NODE_H = 78;

const LAYER_Y = {
  remote: 36,
  edge: 248,
  core: 472,
  access: 696,
};

const FIXED_POS = {
  DirectCODD: { layer: "remote", x: 40 },
  "CAFAP-R1": { layer: "remote", x: 390 },
  "CAFAP-R2": { layer: "remote", x: 740 },
  "MTK-WAN-R1": { layer: "edge", x: 390 },
  "N9K-A": { layer: "core", x: 140 },
  "N9K-B": { layer: "core", x: 620 },
  "WS-C3850-A": { layer: "access", x: 140 },
  "WS-C3850-B": { layer: "access", x: 620 },
};

const COL = 280;
const TOPO_KINDS = new Set(["gre", "lacp", "vpc", "nexthop"]);
const KIND_STROKE = { gre: "#c77dff", lacp: "#4cc9f0", vpc: "#ffd166", nexthop: "#6d8196" };
const KIND_DASH = { gre: "7 5", nexthop: "3 4" };
const KIND_RANK = { lacp: 0, vpc: 1, gre: 2, nexthop: 3 };
const ARROW = { type: MarkerType.ArrowClosed, width: 16, height: 16, color: "#ffe08a" };

function pairKey(a, b) {
  return a < b ? `${a}|${b}` : `${b}|${a}`;
}

function ifaceStamp(link) {
  const a = (link.a_iface || link.a_tunnel || "").toLowerCase();
  const b = (link.b_iface || link.b_tunnel || "").toLowerCase();
  return a <= b ? `${a}|${b}` : `${b}|${a}`;
}

function linkDedupKey(link) {
  if (link.kind === "nexthop") {
    return `nh|${link.source}|${link.target}|${(link.detail || link.label || "").toLowerCase()}`;
  }
  if (link.kind === "lacp" || link.kind === "gre") {
    return `${link.kind}|${pairKey(link.source, link.target)}|${ifaceStamp(link)}`;
  }
  return `${link.kind}|${pairKey(link.source, link.target)}`;
}

export function canvasLinks(mesh) {
  const raw = mesh?.topo_links?.length ? mesh.topo_links : mesh?.links || [];
  const seen = new Set();
  const out = [];
  for (const link of raw) {
    if (!TOPO_KINDS.has(link.kind)) continue;
    const key = linkDedupKey(link);
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(link);
  }
  return out;
}

export function placeDevices(nodes) {
  const used = { remote: [], edge: [], core: [], access: [] };
  const placed = [];
  const leftover = [];
  for (const node of nodes || []) {
    const spec = FIXED_POS[node.identity];
    if (!spec) {
      leftover.push(node);
      continue;
    }
    used[spec.layer].push(spec.x);
    placed.push({ ...node, layer: spec.layer, x: spec.x, y: LAYER_Y[spec.layer] });
  }
  const unknownSw = leftover.filter((node) => node.role === "switch");
  const unknownRt = leftover.filter((node) => node.role !== "switch");

  function park(list, layers) {
    list.forEach((node, i) => {
      const layer = layers[i % layers.length];
      const xs = used[layer];
      const x = xs.length ? Math.max(...xs) + COL : 80;
      xs.push(x);
      placed.push({ ...node, layer, x, y: LAYER_Y[layer] });
    });
  }

  park(unknownSw, ["access", "core"]);
  park(unknownRt, ["remote", "edge"]);
  return placed;
}

function shortDevice(name) {
  const raw = (name || "").trim();
  if (!raw) return "";
  if (/^WS-C3850/i.test(raw)) return raw.replace(/^WS-/i, "");
  if (/^MTK-WAN/i.test(raw)) return "MTK";
  return raw;
}

function splitIfacePair(link) {
  let a = (link.a_iface || "").trim();
  let b = (link.b_iface || "").trim();
  if (!a && !b) {
    const bits = (link.label || "").split(/\s*↔\s*/);
    if (bits.length === 2) {
      a = bits[0].trim();
      b = bits[1].trim();
    }
  }
  return [a, b];
}

function sideRank(name) {
  if (/3850/i.test(name)) return 0;
  if (/MTK/i.test(name)) return 1;
  if (/N9K/i.test(name)) return 2;
  return 3;
}

function shortIface(raw) {
  return (raw || "").trim().replace(/port[\s-]*channel\s*/gi, "Po");
}

function orderEnds(aN, aI, bN, bI) {
  const ra = sideRank(aN);
  const rb = sideRank(bN);
  if (rb < ra || (rb === ra && shortDevice(bN).localeCompare(shortDevice(aN)) < 0)) {
    return [bN, bI, aN, aI];
  }
  return [aN, aI, bN, bI];
}

function linkEnds(link) {
  if (link.kind === "gre") {
    return orderEnds(
      link.source_name || "",
      shortIface(link.a_tunnel || link.a_iface || ""),
      link.target_name || "",
      shortIface(link.b_tunnel || link.b_iface || ""),
    );
  }
  const [aI, bI] = splitIfacePair(link);
  return orderEnds(link.source_name || "", shortIface(aI), link.target_name || "", shortIface(bI));
}

export function catalogLine(link) {
  if (link.kind === "vpc") {
    const names = [shortDevice(link.source_name), shortDevice(link.target_name)].filter(Boolean);
    names.sort((a, b) => a.localeCompare(b));
    if (names.length === 2) return `${names[0]} — ${names[1]}  vpc peer-link`;
    return "vpc peer-link";
  }
  const [aN, aI, bN, bI] = linkEnds(link);
  const left = `${shortDevice(aN)}${aI ? ` ${aI}` : ""}`.trim();
  const right = `${shortDevice(bN)}${bI ? ` ${bI}` : ""}`.trim();
  if (left && right) return `${left} — ${right}`;
  if (aI && bI) return `${aI} — ${bI}`;
  return shortIface(link.label) || (link.kind === "gre" ? "GRE" : "LACP");
}

function catalogTitle(link) {
  if (link.kind === "gre") {
    const a = `${link.source_name || ""} ${link.a_tunnel || link.a_iface || ""}`.trim();
    const b = `${link.target_name || ""} ${link.b_tunnel || link.b_iface || ""}`.trim();
    if (a && b) return `${a} — ${b}`;
  }
  return l2FullText(link) || catalogLine(link);
}

const CAT_KIND = { lacp: 0, vpc: 1, gre: 2 };

export function catalogSortKey(link) {
  const kind = CAT_KIND[link.kind] ?? 9;
  if (link.kind === "vpc") {
    const names = [shortDevice(link.source_name), shortDevice(link.target_name)].filter(Boolean);
    names.sort((a, b) => a.localeCompare(b));
    return `${kind}\0${names.join("\0")}`;
  }
  const [aN, aI, bN, bI] = linkEnds(link);
  return `${kind}\0${sideRank(aN)}\0${shortDevice(aN)}\0${aI}\0${shortDevice(bN)}\0${bI}`;
}

function assignBadges(links, byPos) {
  const idxs = [];
  links.forEach((link, idx) => {
    if (!(link.kind in CAT_KIND)) return;
    if (!byPos.has(link.source) || !byPos.has(link.target)) return;
    idxs.push(idx);
  });
  idxs.sort((i, j) => catalogSortKey(links[i]).localeCompare(catalogSortKey(links[j])));
  const badgeOf = new Map();
  idxs.forEach((idx, n) => badgeOf.set(idx, n + 1));
  return badgeOf;
}

function l2FullText(link) {
  const aName = link.source_name || "";
  const bName = link.target_name || "";
  const [aIf, bIf] = splitIfacePair(link);
  if (link.kind === "vpc") {
    if (aName && bName) return `${aName} — ${bName} · vpc peer-link`;
    return link.label || "vpc peer-link";
  }
  const left = `${aName}${aIf ? ` ${aIf}` : ""}`.trim();
  const right = `${bName}${bIf ? ` ${bIf}` : ""}`.trim();
  if (left && right) return `${left} — ${right}`;
  return link.label || "";
}

function idleLabel(link) {
  if (link.kind === "nexthop") return link.label || (link.detail ? `via ${link.detail}` : "via");
  return catalogLine(link);
}

function hopChip(hop) {
  return hop?.iface || "";
}

function hopLabel(hop) {
  const iface = hop.iface || "";
  const gw = hop.gateway || "";
  if (iface && gw && hop.kind === "l2") return `${iface} → ${gw}`;
  if (iface) return iface;
  if (gw) return gw;
  return "";
}

function hopLegs(hops) {
  const legs = [];
  for (let i = 0; i < (hops || []).length; i += 1) {
    const hop = hops[i];
    const nxt = hop.next_device || hops[i + 1]?.device_id;
    if (!hop.device_id || !nxt || hop.device_id === nxt) continue;
    legs.push({ from: hop.device_id, to: nxt, hop });
  }
  return legs;
}

function hopWantsKind(hop) {
  const blob = `${hop.iface || ""} ${hop.gateway || ""} ${hop.kind || ""}`.toLowerCase();
  if (hop.kind === "l2") return "lacp";
  if (hop.kind === "tunnel" || /tun|gre/.test(blob)) return "gre";
  if (hop.kind === "l3" || hop.kind === "egress") return "nexthop";
  return "";
}

function scoreLink(link, hop) {
  const want = hopWantsKind(hop);
  let score = 0;
  if (want && link.kind === want) score += 8;
  if (want === "lacp" && link.kind === "vpc") score += 4;
  const blob = `${link.label || ""} ${link.a_iface || ""} ${link.b_iface || ""} ${
    link.a_tunnel || ""
  } ${link.b_tunnel || ""} ${link.detail || ""}`.toLowerCase();
  const iface = (hop.iface || "").toLowerCase();
  const gw = (hop.gateway || "").toLowerCase();
  if (iface && blob.includes(iface)) score += 5;
  if (gw && blob.includes(gw)) score += 5;
  return score;
}

function assignLegs(links, legs) {
  const used = new Set();
  const byIdx = new Map();
  for (const leg of legs) {
    const pair = pairKey(leg.from, leg.to);
    let best = -1;
    let bestIdx = -1;
    links.forEach((link, idx) => {
      if (used.has(idx)) return;
      if (pairKey(link.source, link.target) !== pair) return;
      const s = scoreLink(link, leg.hop);
      if (s > best) {
        best = s;
        bestIdx = idx;
      }
    });
    if (bestIdx >= 0) {
      used.add(bestIdx);
      byIdx.set(bestIdx, leg);
    }
  }
  return byIdx;
}

function handlesFor(fromPos, toPos, kind) {
  const dx = toPos.x - fromPos.x;
  const dy = toPos.y - fromPos.y;
  if (kind === "lacp" || kind === "vpc") {
    if (Math.abs(dy) >= 40) {
      return dy >= 0
        ? { sourceHandle: "bottom", targetHandle: "top" }
        : { sourceHandle: "top", targetHandle: "bottom" };
    }
    return dx >= 0
      ? { sourceHandle: "right", targetHandle: "left" }
      : { sourceHandle: "left", targetHandle: "right" };
  }
  if (Math.abs(dy) >= Math.abs(dx)) {
    if (dy >= 0) return { sourceHandle: "bottom", targetHandle: "top" };
    return { sourceHandle: "top", targetHandle: "bottom" };
  }
  if (dx >= 0) return { sourceHandle: "right", targetHandle: "left" };
  return { sourceHandle: "left", targetHandle: "right" };
}

function l2Routes(links, byPos) {
  const extra = links.map(() => ({ chipT: 0.28, stem: 0, elbow: 0.32, nudgeX: 0 }));
  const groups = new Map();
  links.forEach((link, idx) => {
    if (link.kind !== "lacp") return;
    const a = byPos.get(link.source);
    const b = byPos.get(link.target);
    if (!a || !b) return;
    const lower = a.y >= b.y ? link.source : link.target;
    const bag = groups.get(lower) || [];
    bag.push(idx);
    groups.set(lower, bag);
  });
  for (const bag of groups.values()) {
    bag.forEach((idx, slot) => {
      const n = bag.length;
      const zhopa = n === 1 ? 0 : (slot - (n - 1) / 2) * 42;
      extra[idx] = {
        chipT: 0.28,
        stem: zhopa,
        elbow: 0.24 + slot * 0.1,
        nudgeX: zhopa,
      };
    });
  }
  return extra;
}

function pairBends(links) {
  const groups = new Map();
  links.forEach((link, idx) => {
    const key = pairKey(link.source, link.target);
    const bag = groups.get(key) || [];
    bag.push(idx);
    groups.set(key, bag);
  });
  const bends = new Array(links.length).fill(0);
  for (const bag of groups.values()) {
    bag.sort((a, b) => (KIND_RANK[links[a].kind] ?? 9) - (KIND_RANK[links[b].kind] ?? 9) || a - b);
    const n = bag.length;
    bag.forEach((idx, slot) => {
      const zhopa = (slot - (n - 1) / 2) * 44;
      bends[idx] = n === 1 ? 0 : zhopa;
    });
  }
  return bends;
}

function edgeTooltip(link, hop, short) {
  if (link.kind === "nexthop") return /^via\b/i.test(short) ? short : `via ${link.detail || short}`;
  const full = catalogTitle(link) || short;
  if (hop) {
    const hopTxt = hopLabel(hop);
    if (hopTxt && hopTxt !== full) return `${hopTxt} · ${full}`;
    return hopTxt || full;
  }
  return full;
}

export function buildSiteMapModel(mesh, hops = [], selectedId = null, onPick) {
  const devices = placeDevices(mesh?.nodes || []);
  const tracing = (hops || []).length > 0;
  const pathIds = new Set((hops || []).map((h) => h.device_id).filter(Boolean));
  const links = canvasLinks(mesh);
  const legs = hopLegs(hops);
  const byLeg = assignLegs(links, legs);
  const nodes = devices.map((device) => ({
    id: device.id,
    type: "mapDevice",
    position: { x: device.x, y: device.y },
    style: { width: NODE_W, height: NODE_H },
    selected: device.id === selectedId,
    data: {
      id: device.id,
      identity: device.identity,
      role: device.role || "router",
      model: device.model || "",
      rowY: device.y,
      layer: device.layer,
      onPath: tracing && pathIds.has(device.id),
      dim: tracing && !pathIds.has(device.id),
      onPick,
    },
  }));
  const byPos = new Map(nodes.map((node) => [node.id, node.position]));
  const bends = pairBends(links);
  const l2pack = l2Routes(links, byPos);
  const badgeOf = assignBadges(links, byPos);
  const edges = [];
  const catalog = [];
  links.forEach((link, idx) => {
    const leg = byLeg.get(idx);
    const source = leg ? leg.from : link.source;
    const target = leg ? leg.to : link.target;
    if (!byPos.has(source) || !byPos.has(target)) return;
    const onPath = Boolean(leg);
    const dim = tracing && !onPath;
    const short = idleLabel(link);
    const isL2 = link.kind === "lacp" || link.kind === "vpc";
    const hopText = onPath && (isL2 || link.kind === "gre") ? hopChip(leg.hop) : "";
    const badge = badgeOf.get(idx);
    const edge = {
      id: `topo:${link.kind}:${source}:${target}:${ifaceStamp(link)}:${idx}`,
      type: "topo",
      source,
      target,
      ...handlesFor(byPos.get(source), byPos.get(target), link.kind),
      animated: onPath,
      markerEnd: onPath ? ARROW : undefined,
      className: `map-kind-${link.kind} ${onPath ? "is-path" : dim ? "is-dim" : ""}`,
      style: {
        stroke: onPath ? "#ffe08a" : KIND_STROKE[link.kind] || "#7aa2c4",
        strokeWidth: onPath ? 2.8 : link.kind === "nexthop" ? 1.4 : link.kind === "lacp" ? 2.4 : 1.8,
        strokeDasharray: onPath ? undefined : KIND_DASH[link.kind],
      },
      data: {
        kind: link.kind,
        directed: onPath,
        onPath,
        dim,
        badge,
        label: short,
        idleText: short,
        hopText,
        tooltip: edgeTooltip(link, leg?.hop, short),
        showIdleNh: false,
        bend: isL2 ? 0 : bends[idx],
        l2: isL2 ? l2pack[idx] : undefined,
        source_name: link.source_name,
        target_name: link.target_name,
      },
    };
    edges.push(edge);
    if (badge) {
      catalog.push({
        n: badge,
        kind: link.kind,
        group: link.kind === "gre" ? "gre" : "l2",
        text: short,
        title: catalogTitle(link),
        edgeId: edge.id,
        onPath,
      });
    }
  });
  catalog.sort((a, b) => a.n - b.n);
  return { nodes, edges, catalog };
}

function minimapColor(node) {
  if (node.data?.onPath) return "#ffe08a";
  return node.data?.role === "switch" ? "#4cc9f0" : "#f4a261";
}

function CatalogBlock({ title, rows, picked, hotId, onPick, onHover }) {
  return (
    <div className="link-catalog-block" data-cat-group={title.toLowerCase()}>
      <h3>{title}</h3>
      <ul>
        {rows.map((row) => {
          const zatupa = picked === row.edgeId;
          const hot = hotId === row.edgeId;
          return (
            <li key={row.edgeId}>
              <button
                type="button"
                data-catalog-row={String(row.n)}
                data-picked={zatupa ? "1" : "0"}
                data-on-path={row.onPath ? "1" : "0"}
                className={`${zatupa ? "is-picked" : ""} ${hot ? "is-hot" : ""} ${row.onPath ? "on-path" : ""}`.trim()}
                title={row.title}
                onClick={() => onPick(row.edgeId)}
                onMouseEnter={() => onHover(row.edgeId)}
                onMouseLeave={() => onHover(null)}
              >
                <span className={`cat-n kind-${row.kind}`}>{row.n}</span>
                <span className="cat-line">{row.text}</span>
                {row.onPath ? <em>путь</em> : null}
              </button>
            </li>
          );
        })}
      </ul>
    </div>
  );
}

export default function SiteMap({ mesh, hops, selectedId, onSelect }) {
  const [picked, setPicked] = useState(null);
  const [hotId, setHotId] = useState(null);
  const model = useMemo(
    () => buildSiteMapModel(mesh, hops, selectedId, onSelect),
    [mesh, hops, selectedId, onSelect],
  );

  const edges = useMemo(
    () =>
      model.edges.map((edge) => {
        const lit = edge.id === hotId || edge.id === picked;
        const hui = (edge.style?.strokeWidth || 1.8) + (lit ? 1.6 : 0);
        return {
          ...edge,
          className: `${edge.className} ${lit ? "is-picked" : ""}`.trim(),
          style: { ...edge.style, strokeWidth: hui },
          data: {
            ...edge.data,
            hot: lit,
            picked: edge.id === picked,
            onPick: () => setPicked(edge.id),
            onHover: (on) => setHotId(on ? edge.id : null),
          },
        };
      }),
    [model.edges, hotId, picked],
  );

  if (!mesh?.nodes?.length) return null;

  const tracing = (hops || []).length > 0;
  const l2rows = model.catalog.filter((row) => row.group === "l2");
  const greRows = model.catalog.filter((row) => row.group === "gre");

  return (
    <section className="site-map-band">
      <div className="site-map-head">
        <h2>Топология</h2>
        <p>
          номера на рёбрах · подписи в списке · L3 via по наведению
          {tracing ? " · путь" : ""}
        </p>
      </div>
      <div className="site-map">
        <ReactFlow
          nodes={model.nodes}
          edges={edges}
          nodeTypes={NODE_TYPES}
          edgeTypes={EDGE_TYPES}
          onNodeClick={(_, node) => onSelect?.(node.id)}
          onEdgeClick={(_, edge) => setPicked(edge.id)}
          onEdgeMouseEnter={(_, edge) => setHotId(edge.id)}
          onEdgeMouseLeave={() => setHotId(null)}
          connectionMode={ConnectionMode.Loose}
          fitView
          fitViewOptions={{ padding: 0.15 }}
          minZoom={0.45}
          maxZoom={1.6}
          nodesDraggable={false}
          nodesConnectable={false}
          elementsSelectable
          panOnDrag
          zoomOnScroll
          proOptions={{ hideAttribution: false }}
        >
          <Controls showInteractive={false} />
          <MiniMap pannable zoomable nodeColor={minimapColor} maskColor="rgba(8,12,18,0.72)" />
        </ReactFlow>
      </div>
      <div className="map-edge-audit" aria-hidden="true">
        {edges.map((edge) => (
          <span
            key={edge.id}
            data-map-edge={edge.id}
            data-kind={edge.data.kind}
            data-directed={edge.data.directed ? "1" : "0"}
            data-source={edge.source}
            data-target={edge.target}
            data-label={edge.data.label || ""}
            data-picked={edge.data.picked ? "1" : "0"}
            data-badge={edge.data.badge ? String(edge.data.badge) : ""}
            title={edge.data.tooltip || ""}
          />
        ))}
      </div>
      <div className="map-edge-chips" aria-hidden="true">
        {edges.map((edge) =>
          edge.data.badge ? (
            <span
              key={`badge:${edge.id}`}
              className={`topo-edge-badge kind-${edge.data.kind}`}
              data-edge-badge={String(edge.data.badge)}
              data-kind={edge.data.kind}
            >
              {edge.data.badge}
            </span>
          ) : null,
        )}
        {edges.map((edge) => {
          const chip = edgeChipText(edge.data, edge.data.hot);
          if (!chip) return null;
          return (
            <span
              key={`chip:${edge.id}`}
              className={`topo-edge-chip kind-${edge.data.kind} ${edge.data.onPath ? "is-path" : ""}`}
              data-edge-label={chip}
              data-kind={edge.data.kind}
              title={edge.data.tooltip || chip}
            >
              {chip}
            </span>
          );
        })}
      </div>
      {model.catalog.length ? (
        <nav
          className="link-catalog"
          data-link-catalog
          data-cols={l2rows.length && greRows.length ? "2" : "1"}
          aria-label="Каталог связей"
        >
          {l2rows.length ? (
            <CatalogBlock
              title="L2"
              rows={l2rows}
              picked={picked}
              hotId={hotId}
              onPick={setPicked}
              onHover={setHotId}
            />
          ) : null}
          {greRows.length ? (
            <CatalogBlock
              title="GRE"
              rows={greRows}
              picked={picked}
              hotId={hotId}
              onPick={setPicked}
              onHover={setHotId}
            />
          ) : null}
        </nav>
      ) : null}
      {mesh.unmatched?.length ? (
        <p className="hint">
          GRE без второй стороны:{" "}
          {mesh.unmatched
            .map(
              (tun) =>
                `${tun.device_name ? `${tun.device_name} ` : ""}${tun.name}${tun.comment ? ` (${tun.comment})` : ""}`,
            )
            .join(", ")}
          .
        </p>
      ) : null}
    </section>
  );
}
