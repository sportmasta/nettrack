import { useLayoutEffect, useRef, useState } from "react";

const KIND_LABEL = {
  gre: "GRE",
  lacp: "LACP",
  vpc: "vPC",
  svi: "SVI",
  nexthop: "NH",
};

function dstLine(rows, verb) {
  if (!rows?.length) return null;
  return (
    <p>
      {verb} {rows.length}: {rows.map((row) => row.dst).join(", ")}
    </p>
  );
}

function linkKey(link) {
  return `${link.kind || "gre"}-${link.source}-${link.target}-${link.a_iface || link.a_ip || link.label}`;
}

function onPath(link, hops) {
  if (!hops?.length) return false;
  for (let i = 0; i < hops.length; i += 1) {
    const a = hops[i].device_id;
    const b = hops[i].next_device || hops[i + 1]?.device_id;
    if (!a || !b) continue;
    if ((link.source === a && link.target === b) || (link.source === b && link.target === a)) return true;
  }
  return false;
}

function MeshWires({ mesh, hops, pathIds, tracing }) {
  const rootRef = useRef(null);
  const [wires, setWires] = useState([]);

  useLayoutEffect(() => {
    const root = rootRef.current;
    if (!root || !mesh?.links?.length) {
      setWires([]);
      return;
    }
    const origin = root.getBoundingClientRect();
    const points = {};
    for (const el of root.querySelectorAll("[data-dev]")) {
      const box = el.getBoundingClientRect();
      points[el.dataset.dev] = {
        x: box.left - origin.left + box.width / 2,
        y: box.top - origin.top + box.height / 2,
      };
    }
    setWires(
      mesh.links
        .map((link) => {
          const a = points[link.source];
          const b = points[link.target];
          if (!a || !b) return null;
          return { ...link, x1: a.x, y1: a.y, x2: b.x, y2: b.y, hot: onPath(link, hops) };
        })
        .filter(Boolean),
    );
  }, [mesh, hops]);

  return (
    <div className="mesh" ref={rootRef}>
      <svg className="mesh-wires" aria-hidden="true">
        {wires.map((wire) => (
          <g key={linkKey(wire)}>
            <line
              className={`${wire.kind || "gre"} ${wire.hot ? "is-path" : tracing ? "is-dim" : ""}`}
              x1={wire.x1}
              y1={wire.y1}
              x2={wire.x2}
              y2={wire.y2}
            />
            <text x={(wire.x1 + wire.x2) / 2} y={(wire.y1 + wire.y2) / 2 - 8}>
              {KIND_LABEL[wire.kind] || wire.kind || ""} {wire.label}
            </text>
          </g>
        ))}
      </svg>
      <div className="mesh-nodes">
        {mesh.nodes.map((node) => (
          <article
            key={node.id}
            data-dev={node.id}
            className={`card NEIGHBOR ${node.role || "router"} ${
              tracing && pathIds.has(node.id) ? "is-path" : tracing ? "is-dim" : ""
            }`}
          >
            <header>
              <strong>{node.identity}</strong>
              <span>{node.role === "switch" ? "switch" : "router"}</span>
            </header>
            {node.model ? <p>{node.model}</p> : null}
            {(node.prefixes || []).slice(0, 3).map((prefix) => (
              <p key={prefix}>{prefix}</p>
            ))}
          </article>
        ))}
      </div>
    </div>
  );
}

export default function SiteMesh({ mesh, hops }) {
  const pathIds = new Set((hops || []).map((h) => h.device_id).filter(Boolean));
  const tracing = (hops || []).length > 0;

  if (!mesh?.nodes?.length || mesh.nodes.length < 2) return null;

  return (
    <section className="mesh-band">
      <h2>Связи между устройствами</h2>
      <MeshWires mesh={mesh} hops={hops} pathIds={pathIds} tracing={tracing} />
      {mesh.unmatched?.length ? (
        <p className="hint">
          GRE без второй стороны в схеме:{" "}
          {mesh.unmatched
            .map(
              (tun) =>
                `${tun.device_name ? `${tun.device_name} ` : ""}${tun.name}${tun.comment ? ` (${tun.comment})` : ""}`,
            )
            .join(", ")}
          .
        </p>
      ) : null}
      <ul className="mesh-legend">
        {mesh.links.map((link) => (
          <li
            key={linkKey(link)}
            className={tracing && onPath(link, hops) ? "is-path" : tracing ? "is-dim" : ""}
          >
            <strong>{link.source_name}</strong>{" "}
            <em className={`kind ${link.kind || "gre"}`}>{KIND_LABEL[link.kind] || link.kind || "GRE"}</em>{" "}
            {link.label} <strong>{link.target_name}</strong>
            {link.detail && link.kind === "gre" ? ` — ${link.detail}` : ""}
            {link.kind === "gre" ? (
              <div className="mesh-exchange">
                {dstLine(link.advertised, "передано")}
                {dstLine(link.received, "получено")}
                {dstLine(link.forwarded, "транзит")}
              </div>
            ) : null}
          </li>
        ))}
      </ul>
    </section>
  );
}
