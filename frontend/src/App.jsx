import { useEffect, useMemo, useState } from "react";
import { addDevice, getGraph, importRsc, listSnapshots, tracePath } from "./api.js";
import Legend from "./components/Legend.jsx";
import PathTrace from "./components/PathTrace.jsx";
import RouteTable from "./components/RouteTable.jsx";
import SiteMap from "./components/SiteMap.jsx";
import TopologyCanvas from "./components/TopologyCanvas.jsx";

function deviceGraphsOf(graph) {
  if (!graph) return [];
  if (graph.device_graphs?.length) return graph.device_graphs;
  return [{ ...graph, device_id: graph.router?.device_id || "dev-0", role: graph.router?.role || "router" }];
}

function flattenRoutes(graph) {
  const graphs = deviceGraphsOf(graph);
  if (graphs.length) return graphs.flatMap((item) => item.routes || []);
  return graph?.routes || [];
}

function hitsForRoute(route, exchange) {
  if (!route || !exchange?.length) return [];
  return exchange.filter((item) => {
    if (item.dst !== route.dst) return false;
    if (route.device_name && item.from !== route.device_name && item.to !== route.device_name) return false;
    if (
      route.interface &&
      item.via_tunnel !== route.interface &&
      item.peer_tunnel !== route.interface
    ) {
      return false;
    }
    return true;
  });
}

function roleLabel(role) {
  if (role === "advertised") return "передано";
  if (role === "received") return "получено";
  if (role === "forwarded") return "транзит";
  return role;
}

function hopIfaces(hops, deviceId) {
  return (hops || [])
    .filter((h) => h.device_id === deviceId)
    .flatMap((h) => [h.iface, h.vlan ? `VLAN${h.vlan}` : "", h.vlan ? `Vlan${h.vlan}` : ""])
    .filter(Boolean);
}

export default function App() {
  const [graph, setGraph] = useState(null);
  const [snapshotId, setSnapshotId] = useState(null);
  const [error, setError] = useState("");
  const [selectedRouteId, setSelectedRouteId] = useState(null);
  const [query, setQuery] = useState("");
  const [direction, setDirection] = useState("all");
  const [deviceFilter, setDeviceFilter] = useState("all");
  const [onlyEnabled, setOnlyEnabled] = useState(true);
  const [trace, setTrace] = useState(null);
  const [traceBusy, setTraceBusy] = useState(false);
  const [traceError, setTraceError] = useState("");
  const [selectedDeviceId, setSelectedDeviceId] = useState(null);

  async function loadSnapshot(id) {
    const data = await getGraph(id);
    setSnapshotId(id);
    setGraph(data);
    setSelectedRouteId(null);
    setDeviceFilter("all");
    setTrace(null);
    setSelectedDeviceId(null);
  }

  async function loadLatest() {
    const snaps = await listSnapshots();
    if (!snaps.length) {
      setGraph(null);
      setSnapshotId(null);
      return;
    }
    await loadSnapshot(snaps[0].id);
  }

  useEffect(() => {
    loadLatest().catch((err) => setError(err.message));
  }, []);

  async function onAddDevice(ev) {
    const file = ev.target.files?.[0];
    ev.target.value = "";
    if (!file) return;
    setError("");
    try {
      if (snapshotId) {
        await addDevice(snapshotId, file);
        await loadSnapshot(snapshotId);
      } else {
        const created = await importRsc(file);
        await loadSnapshot(created.id);
      }
    } catch (err) {
      setError(err.message);
    }
  }

  async function onReplaceSite(ev) {
    const file = ev.target.files?.[0];
    ev.target.value = "";
    if (!file) return;
    setError("");
    try {
      const created = await importRsc(file);
      await loadSnapshot(created.id);
    } catch (err) {
      setError(err.message);
    }
  }

  async function onTrace(payload) {
    if (!snapshotId) return;
    setTraceBusy(true);
    setTraceError("");
    try {
      const result = await tracePath(snapshotId, payload);
      setTrace(result);
      setSelectedRouteId(null);
    } catch (err) {
      setTraceError(err.message);
    } finally {
      setTraceBusy(false);
    }
  }

  const schematics = useMemo(() => deviceGraphsOf(graph), [graph]);
  const routes = useMemo(() => flattenRoutes(graph), [graph]);
  const selected = useMemo(() => routes.find((r) => r.id === selectedRouteId), [routes, selectedRouteId]);
  const exchangeHits = useMemo(() => hitsForRoute(selected, graph?.exchange), [selected, graph]);
  const enabledCount = schematics.reduce((n, item) => n + (item.stats?.routes_enabled || 0), 0);
  const routeCount = schematics.reduce((n, item) => n + (item.stats?.routes || 0), 0);
  const hops = trace?.hops || [];
  const pathIds = new Set(hops.map((h) => h.device_id));
  const tracing = hops.length > 0;
  const activeDeviceId = useMemo(() => {
    if (selectedDeviceId && schematics.some((item) => item.device_id === selectedDeviceId)) {
      return selectedDeviceId;
    }
    return schematics[0]?.device_id || graph?.devices?.[0]?.id || null;
  }, [selectedDeviceId, schematics, graph]);
  const selectedSchematic = schematics.find((item) => item.device_id === activeDeviceId) || schematics[0];
  const onPath = tracing && selectedSchematic && pathIds.has(selectedSchematic.device_id);

  function pickDevice(id) {
    setSelectedDeviceId(id);
    setDeviceFilter(id);
    if (selected && selected.device_id !== id) setSelectedRouteId(null);
  }

  return (
    <div className="app">
      <header className="topbar">
        <div className="brand">
          <strong>NetTrack</strong>
          <span>
            {graph?.router?.name || "нет снимка"} · {graph?.router?.model || "импортируйте .rsc / .conf"}
            {graph
              ? ` · ${schematics.length} устр. · маршрутов ${enabledCount}/${routeCount}`
              : ""}
          </span>
        </div>
        <div className="topbar-actions">
          <label className="file-btn">
            Добавить устройство
            <input type="file" accept=".rsc,.txt,.conf" hidden onChange={onAddDevice} />
          </label>
          <label className="ghost">
            Новая схема
            <input type="file" accept=".rsc,.txt,.conf" hidden onChange={onReplaceSite} />
          </label>
        </div>
      </header>
      <div className="workspace">
        <div className="canvas-wrap">
          {graph ? (
            <SiteMap
              mesh={
                graph.mesh?.nodes?.length
                  ? graph.mesh
                  : {
                      ...(graph.mesh || {}),
                      nodes: (graph.devices || []).map((device) => ({
                        id: device.id,
                        identity: device.identity,
                        role: device.role,
                        model: device.model,
                      })),
                    }
              }
              hops={hops}
              selectedId={activeDeviceId}
              onSelect={pickDevice}
            />
          ) : null}
          {selectedSchematic ? (
            <section
              className={`schematic-block ${
                selected?.device_id && selected.device_id === selectedSchematic.device_id ? "is-target" : ""
              } ${tracing && onPath ? "is-path" : ""}`}
            >
              <TopologyCanvas
                graph={selectedSchematic}
                selectedRouteId={
                  selected?.device_id === selectedSchematic.device_id ? selectedRouteId : null
                }
                pathIfaces={onPath ? hopIfaces(hops, selectedSchematic.device_id) : undefined}
                onPath={onPath}
              />
            </section>
          ) : null}
          {graph && schematics.length < 2 ? (
            <section className="neighbors-band">
              <h2>Ещё устройства</h2>
              <p className="hint">
                Добавьте `/export` MikroTik или Cisco `show running-config` — на топологии появятся L2 / L3 / GRE.
              </p>
            </section>
          ) : null}
        </div>
        <aside className="sidebar">
          <header>
            <div>Таблица маршрутов</div>
            {error ? <div className="status-err">{error}</div> : null}
          </header>
          <PathTrace
            devices={graph?.devices || schematics.map((item) => ({
              id: item.device_id,
              identity: item.router?.name,
              role: item.role,
              attachments: [],
            }))}
            snapshotId={snapshotId}
            onResult={onTrace}
            hops={hops}
            status={trace?.status}
            reason={trace?.reason}
            busy={traceBusy}
            error={traceError}
          />
          <Legend />
          <div className="filters">
            <input
              placeholder="поиск dst / gw / comment"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
            />
            <select aria-label="направление" value={direction} onChange={(e) => setDirection(e.target.value)}>
              <option value="all">все направления</option>
              <option value="egress">egress</option>
              <option value="ingress">ingress</option>
              <option value="local">local</option>
              <option value="tunnel">tunnel</option>
              <option value="policy">policy</option>
            </select>
            <select aria-label="устройство" value={deviceFilter} onChange={(e) => setDeviceFilter(e.target.value)}>
              <option value="all">все устройства</option>
              {(graph?.devices || schematics.map((item) => ({
                id: item.device_id,
                identity: item.router?.name,
              }))).map((device) => (
                <option key={device.id} value={device.id}>
                  {device.identity}
                </option>
              ))}
            </select>
            <button className="ghost" onClick={() => setOnlyEnabled((v) => !v)}>
              {onlyEnabled ? "только enabled" : "включая disabled"}
            </button>
          </div>
          <RouteTable
            routes={routes}
            selectedId={selectedRouteId}
            onSelect={setSelectedRouteId}
            query={query}
            onlyEnabled={onlyEnabled}
            direction={direction}
            deviceFilter={deviceFilter}
          />
          <div className="details">
            {selected ? (
              <>
                <div>
                  <strong>{selected.dst}</strong> → {selected.gateway}
                </div>
                <div>
                  iface {selected.interface || "—"} · table {selected.routing_table} · dist {selected.distance}
                </div>
                <div>устройство {selected.device_name || graph?.router?.name || "—"}</div>
                <div className={`dir ${selected.direction}`}>{selected.direction}</div>
                {exchangeHits.map((hit) => (
                  <div key={`${hit.role}-${hit.from}-${hit.to}-${hit.via_tunnel}`}>
                    {roleLabel(hit.role)} {hit.from} → {hit.to}
                    {hit.via_tunnel ? ` · ${hit.via_tunnel}` : ""}
                    {hit.peer_tunnel ? ` ↔ ${hit.peer_tunnel}` : ""}
                    {hit.origin ? ` · ${hit.origin}` : ""}
                  </div>
                ))}
                <div>{selected.comment}</div>
              </>
            ) : tracing ? (
              <div>Путь клиента — стрелки на топологии по ходу hops.</div>
            ) : (
              <div>Выберите маршрут или постройте путь клиента.</div>
            )}
          </div>
        </aside>
      </div>
    </div>
  );
}
