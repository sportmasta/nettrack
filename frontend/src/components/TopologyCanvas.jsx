function localNodeId(id) {
  if (!id) return id;
  return id.replace(/^dev-\d+:/, "");
}

function isHot(id, route, pathIfaces) {
  if (pathIfaces?.length) {
    const local = localNodeId(id);
    if (local === "router") return true;
    for (const name of pathIfaces) {
      if (!name) continue;
      if (local === `iface:${name}` || local === `iface:VLAN${name}` || local.endsWith(`:${name}`)) return true;
      if (local === `iface:${name.replace(/^VLAN/i, "Vlan")}`) return true;
    }
  }
  if (!route || !id) return false;
  const local = localNodeId(id);
  if (local === "router") return true;
  if (route.interface && local === `iface:${route.interface}`) return true;
  if (route.gateway && local === `iface:${route.gateway}`) return true;
  if (route.direction === "egress" && local === "wan-uplink") return true;
  if (route.direction === "ingress" && local === "service:inbound") return true;
  return false;
}

function Card({ node, route, tone, pathIfaces }) {
  const hot =
    isHot(node.id, route, pathIfaces) || (tone === "WAN" && route?.direction === "egress" && node.data?.kind === "pppoe");
  return (
    <article className={`card ${tone} ${hot ? "hot" : ""}`}>
      <header>
        <strong>{node.data.label}</strong>
        <span>{tone}</span>
      </header>
      {(node.data.lines || []).map((line) => (
        <p key={line}>{line}</p>
      ))}
    </article>
  );
}

function Port({ port }) {
  const label = port.name.replace("sfp-sfpplus", "sfp+");
  return (
    <li className={`jack ${port.kind} ${port.zone}`} title={port.comment || port.name}>
      {label}
    </li>
  );
}

export default function TopologyCanvas({ graph, selectedRouteId, pathIfaces, onPath }) {
  if (!graph) return null;
  const route = (graph.routes || []).find((r) => r.id === selectedRouteId);
  const visible = graph.nodes.filter((n) => !n.data?.hidden && (n.position?.x ?? 0) > -1000);
  const lan = visible.filter((n) => n.type === "interface" && n.data.zone === "LAN" && n.data.kind !== "bonding");
  const wan = visible.filter((n) => n.type === "interface" && n.data.zone === "WAN");
  const vpn = visible.filter((n) => n.type === "interface" && n.data.zone === "VPN");
  const lacp = visible.find((n) => n.data?.kind === "bonding");
  const inbound = visible.find((n) => localNodeId(n.id) === "service:inbound");
  const router = visible.find((n) => n.type === "router");
  const ports = router?.data?.ports || [];
  const identity = router?.data?.label || graph.router?.name || "";
  const model = router?.data?.model || graph.router?.model || "";
  const uplinkSlaves = lacp?.data?.lines?.find((l) => l.includes("sfp")) || lacp?.data?.lines?.[0];

  return (
    <div
      className={`schematic ${route ? `flow-${route.direction}` : ""} ${onPath ? "on-path" : ""}`}
      data-device={graph.device_id || "dev-0"}
    >
      <p className="schematic-kicker">
        <strong>{identity}</strong>
        <em>{graph.role === "switch" ? "switch" : graph.role || "router"}</em>
      </p>
      <section className="col lan">
        <h2>LAN</h2>
        <div className="stack">
          {lan.map((node) => (
            <Card key={node.id} node={node} route={route} tone="LAN" pathIfaces={pathIfaces} />
          ))}
        </div>
      </section>

      <div className="spine lan-spine" aria-hidden="true" />

      <section className="col core">
        <div className={`device ${isHot(router?.id || "router", route, pathIfaces) || onPath ? "hot" : ""}`}>
          <div className="device-head">
            <h3>{identity}</h3>
            <small>{model}</small>
          </div>
          {ports.length ? (
            <ul className="jacks">
              {ports.map((port) => (
                <Port key={port.name} port={port} />
              ))}
            </ul>
          ) : null}
          {lacp ? (
            <div className="uplink">
              Uplink {lacp.data.label}
              {uplinkSlaves ? `: ${uplinkSlaves}` : ""}
            </div>
          ) : null}
        </div>
      </section>

      <div className="spine wan-spine" aria-hidden="true" />

      <section className="col wan">
        <h2>WAN</h2>
        <div className="stack">
          {wan.map((node) => (
            <Card
              key={node.id}
              node={{ ...node, id: node.data?.kind === "pppoe" ? "wan-uplink" : node.id }}
              route={route}
              tone="WAN"
              pathIfaces={pathIfaces}
            />
          ))}
          {inbound ? (
            <article className={`card WAN inbound ${isHot(inbound.id, route, pathIfaces) ? "hot" : ""}`}>
              <header>
                <strong>Входящий трафик</strong>
                <span>DNAT</span>
              </header>
              {(inbound.data.lines || []).map((line) => (
                <p key={line}>{line}</p>
              ))}
            </article>
          ) : null}
        </div>
      </section>

      <section className="vpn-band">
        <div className="vpn-join" aria-hidden="true" />
        <h2>VPN</h2>
        <div className="vpn-grid">
          {vpn.map((node) => (
            <Card key={node.id} node={node} route={route} tone="VPN" pathIfaces={pathIfaces} />
          ))}
        </div>
      </section>
    </div>
  );
}
