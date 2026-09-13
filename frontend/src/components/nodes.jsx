import { Handle, Position } from "@xyflow/react";

export function RouterNode({ data }) {
  const ports = data.ports || [];
  return (
    <div className="router-node">
      <Handle type="target" position={Position.Left} />
      <Handle type="source" position={Position.Right} />
      <Handle type="source" position={Position.Bottom} id="south" />
      <div className="router-head">
        <h3>{data.label}</h3>
        <small>{data.model}</small>
      </div>
      <div className="port-grid">
        {ports.map((port) => (
          <div key={port.name} className={`port ${port.kind} ${port.zone}`} title={port.comment || port.name}>
            {port.name.replace("sfp-sfpplus", "sfp+")}
          </div>
        ))}
      </div>
    </div>
  );
}

export function IfaceCard({ data }) {
  return (
    <div className={`iface-card ${data.zone || ""}`}>
      <Handle type="target" position={Position.Right} />
      <Handle type="source" position={Position.Left} />
      <Handle type="target" position={Position.Top} />
      <Handle type="source" position={Position.Bottom} />
      <div className="iface-card-head">
        <strong>{data.label}</strong>
        <span className={`zone-pill ${data.zone}`}>{data.zone}</span>
      </div>
      {(data.lines || []).map((line) => (
        <small key={line}>{line}</small>
      ))}
    </div>
  );
}

export function ZoneLabel({ data }) {
  return <div className={`zone-title ${data.zone || ""}`}>{data.label}</div>;
}

export function ServiceCard({ data }) {
  return (
    <div className={`iface-card ${data.zone || ""}`}>
      <Handle type="target" position={Position.Left} />
      <div className="iface-card-head">
        <strong>{data.label}</strong>
        <span className="zone-pill WAN">IN</span>
      </div>
      {(data.lines || []).map((line) => (
        <small key={line}>{line}</small>
      ))}
      {data.extra ? <small>и ещё {data.extra}</small> : null}
    </div>
  );
}

export function HiddenNode() {
  return <div style={{ width: 1, height: 1, opacity: 0 }} />;
}

export function MapDeviceNode({ data, selected }) {
  return (
    <div
      className={`map-device ${data.role || "router"} ${data.onPath ? "is-path" : ""} ${
        data.dim ? "is-dim" : ""
      } ${selected ? "is-selected" : ""}`}
      data-map-node={data.identity}
      data-device={data.id}
      data-map-y={data.rowY}
      data-map-layer={data.layer || ""}
      data-role={data.role || "router"}
      onClick={(ev) => {
        ev.stopPropagation();
        data.onPick?.(data.id);
      }}
    >
      <Handle type="source" position={Position.Left} id="left" />
      <Handle type="source" position={Position.Right} id="right" />
      <Handle type="source" position={Position.Top} id="top" />
      <Handle type="source" position={Position.Bottom} id="bottom" />
      <strong>{data.identity}</strong>
      <span>{data.role === "switch" ? "switch" : "router"}</span>
      {data.model ? <em>{data.model}</em> : null}
    </div>
  );
}
