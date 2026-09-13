import { fireEvent, render, screen } from "@testing-library/react";
import { useState } from "react";
import RouteTable from "./components/RouteTable.jsx";
import Legend from "./components/Legend.jsx";
import PathTrace from "./components/PathTrace.jsx";
import SiteMap from "./components/SiteMap.jsx";
import TopologyCanvas from "./components/TopologyCanvas.jsx";

const routes = [
  {
    id: "dev-0:route-0",
    dst: "0.0.0.0/0",
    gateway: "PPP-Rostelecom",
    interface: "PPP-Rostelecom",
    routing_table: "main",
    comment: "WAN",
    disabled: false,
    direction: "egress",
    device_id: "dev-0",
    device_name: "MTK-WAN-R1",
  },
  {
    id: "dev-1:route-1",
    dst: "10.38.0.0/16",
    gateway: "Tun04",
    interface: "Tun04",
    routing_table: "main",
    comment: "direct",
    disabled: false,
    direction: "tunnel",
    device_id: "dev-1",
    device_name: "CAFAP-R1",
  },
];

const hubGraph = {
  device_id: "dev-0",
  role: "router",
  router: { name: "MTK-WAN-R1", model: "CCR2004-16G-2S+" },
  routes: [],
  nodes: [
    {
      id: "dev-0:router",
      type: "router",
      position: { x: 0, y: 0 },
      data: { label: "MTK-WAN-R1", model: "CCR2004-16G-2S+", ports: [{ name: "ether16", kind: "ether", zone: "WAN" }] },
    },
    {
      id: "dev-0:iface:VLAN2",
      type: "interface",
      position: { x: 0, y: 0 },
      data: { label: "VLAN2", zone: "LAN", kind: "vlan", lines: ["10.255.63.0/26"] },
    },
    {
      id: "dev-0:iface:PPP-Rostelecom",
      type: "interface",
      position: { x: 0, y: 0 },
      data: { label: "PPP-Rostelecom", zone: "WAN", kind: "pppoe", lines: ["default"] },
    },
    {
      id: "dev-0:iface:Tun04",
      type: "interface",
      position: { x: 0, y: 0 },
      data: { label: "Tun04", zone: "VPN", kind: "gre", lines: ["toDirect"] },
    },
  ],
};

const neighborGraph = {
  device_id: "dev-1",
  role: "router",
  router: { name: "CAFAP-R1", model: "RB4011iGS+" },
  routes: [],
  nodes: [
    {
      id: "dev-1:router",
      type: "router",
      position: { x: 0, y: 0 },
      data: { label: "CAFAP-R1", model: "RB4011iGS+", ports: [{ name: "ether1", kind: "ether", zone: "WAN" }] },
    },
    {
      id: "dev-1:iface:VLAN10",
      type: "interface",
      position: { x: 0, y: 0 },
      data: { label: "VLAN10", zone: "LAN", kind: "vlan", lines: ["10.20.0.0/24"] },
    },
    {
      id: "dev-1:iface:gre-hub",
      type: "interface",
      position: { x: 0, y: 0 },
      data: { label: "gre-hub", zone: "VPN", kind: "gre", lines: ["to MTK-WAN-R1"] },
    },
  ],
};

test("route table filters by query and highlights selection", () => {
  render(
    <RouteTable
      routes={routes}
      selectedId="dev-1:route-1"
      onSelect={() => {}}
      query="Tun04"
      onlyEnabled
      direction="all"
    />,
  );
  expect(screen.getByText("10.38.0.0/16")).toBeInTheDocument();
  expect(screen.queryByText("0.0.0.0/0")).not.toBeInTheDocument();
  expect(document.querySelector("tr.active")).toHaveTextContent("Tun04");
});

test("route table filters by device", () => {
  render(
    <RouteTable
      routes={routes}
      selectedId={null}
      onSelect={() => {}}
      query=""
      onlyEnabled
      direction="all"
      deviceFilter="dev-1"
    />,
  );
  expect(screen.getByText("10.38.0.0/16")).toBeInTheDocument();
  expect(screen.getByText("CAFAP-R1")).toBeInTheDocument();
  expect(screen.queryByText("0.0.0.0/0")).not.toBeInTheDocument();
});

test("legend lists topology link kinds", () => {
  render(<Legend />);
  expect(screen.getByText("L2 LACP")).toBeInTheDocument();
  expect(screen.getByText("L2 vPC")).toBeInTheDocument();
  expect(screen.getByText("L3 via")).toBeInTheDocument();
  expect(screen.getByText("GRE Tun")).toBeInTheDocument();
  expect(screen.getByText("путь")).toBeInTheDocument();
});

test("schematic renders zone columns without graph handles", () => {
  render(<TopologyCanvas selectedRouteId={null} graph={hubGraph} />);
  expect(screen.getByRole("heading", { name: "LAN" })).toBeInTheDocument();
  expect(screen.getByRole("heading", { name: "WAN" })).toBeInTheDocument();
  expect(screen.getByRole("heading", { name: "VPN" })).toBeInTheDocument();
  expect(screen.getByText("VLAN2")).toBeInTheDocument();
  expect(screen.getByText("Tun04")).toBeInTheDocument();
  expect(screen.getAllByText("MTK-WAN-R1").length).toBeGreaterThan(0);
  expect(screen.getAllByText("CCR2004-16G-2S+").length).toBeGreaterThan(0);
  expect(screen.queryByRole("heading", { name: "Связи между устройствами" })).not.toBeInTheDocument();
});

test("renders a schematic per device graph", () => {
  render(
    <>
      <TopologyCanvas selectedRouteId={null} graph={hubGraph} />
      <TopologyCanvas selectedRouteId={null} graph={neighborGraph} />
    </>,
  );
  expect(screen.getAllByRole("heading", { name: "LAN" })).toHaveLength(2);
  expect(screen.getByText("VLAN10")).toBeInTheDocument();
  expect(screen.getByText("gre-hub")).toBeInTheDocument();
  expect(document.querySelectorAll("[data-device]")).toHaveLength(2);
  expect(document.querySelector('[data-device="dev-1"]')).toHaveTextContent("CAFAP-R1");
});

const twoNodeMesh = {
  nodes: [
    { id: "dev-0", identity: "MTK-WAN-R1", role: "router", model: "CCR2004-16G-2S+" },
    { id: "dev-1", identity: "CAFAP-R1", role: "router", model: "RB4011iGS+" },
  ],
  links: [
    {
      source: "dev-0",
      target: "dev-1",
      source_name: "MTK-WAN-R1",
      target_name: "CAFAP-R1",
      kind: "gre",
      label: "Tun01 ↔ gre-hub",
      advertised: [{ dst: "10.255.63.0/26", from: "MTK-WAN-R1", to: "CAFAP-R1" }],
      received: [{ dst: "10.20.0.0/24", from: "CAFAP-R1", to: "MTK-WAN-R1" }],
      forwarded: [],
    },
    {
      source: "dev-0",
      target: "dev-1",
      source_name: "MTK-WAN-R1",
      target_name: "CAFAP-R1",
      kind: "svi",
      label: "VLAN2 10.255.63.0/26",
    },
    {
      source: "dev-0",
      target: "dev-1",
      source_name: "MTK-WAN-R1",
      target_name: "CAFAP-R1",
      kind: "nexthop",
      label: "via 10.255.63.254",
    },
  ],
  topo_links: [
    {
      source: "dev-0",
      target: "dev-1",
      source_name: "MTK-WAN-R1",
      target_name: "CAFAP-R1",
      kind: "gre",
      label: "Tun01 ↔ gre-hub",
      a_tunnel: "Tun01",
      b_tunnel: "gre-hub",
      advertised: [{ dst: "10.255.63.0/26", from: "MTK-WAN-R1", to: "CAFAP-R1" }],
      received: [{ dst: "10.20.0.0/24", from: "CAFAP-R1", to: "MTK-WAN-R1" }],
      forwarded: [],
    },
    {
      source: "dev-0",
      target: "dev-1",
      source_name: "MTK-WAN-R1",
      target_name: "CAFAP-R1",
      kind: "nexthop",
      label: "via 10.255.63.254",
      detail: "10.255.63.254",
    },
  ],
  unmatched: [{ name: "Tun10", comment: "home" }],
};

test("map catalog lists GRE pair and unmatched hint", () => {
  render(<SiteMap mesh={twoNodeMesh} hops={[]} selectedId="dev-0" onSelect={() => {}} />);
  expect(screen.getByRole("heading", { name: "Топология" })).toBeInTheDocument();
  const cat = document.querySelector("[data-link-catalog]");
  expect(cat.textContent).toMatch(/Tun01/);
  expect(cat.textContent).toMatch(/CAFAP-R1|gre-hub/);
  expect(screen.queryByText(/передано 1: 10\.255\.63\.0\/26/)).not.toBeInTheDocument();
  expect(screen.getByText(/GRE без второй стороны/)).toBeInTheDocument();
  expect(screen.getByText(/Tun10/)).toBeInTheDocument();
});

test("schematic role is router not hub", () => {
  render(<TopologyCanvas selectedRouteId={null} graph={hubGraph} />);
  expect(document.querySelector(".schematic-kicker em")).toHaveTextContent("router");
  expect(screen.queryByText("hub")).not.toBeInTheDocument();
  expect(screen.queryByText("peer")).not.toBeInTheDocument();
});

test("map shows lacp kind and switch role", () => {
  render(
    <SiteMap
      mesh={{
        nodes: [
          { id: "dev-0", identity: "MTK-WAN-R1", role: "router", prefixes: [] },
          { id: "dev-1", identity: "N9K-A", role: "switch", prefixes: [] },
        ],
        links: [
          {
            source: "dev-0",
            target: "dev-1",
            source_name: "MTK-WAN-R1",
            target_name: "N9K-A",
            kind: "lacp",
            label: "LACP1 ↔ Po3",
          },
        ],
        unmatched: [],
      }}
      hops={[]}
      selectedId="dev-0"
      onSelect={() => {}}
    />,
  );
  expect(document.querySelector('[data-kind="lacp"]')).toBeTruthy();
  expect(screen.getByText("switch")).toBeInTheDocument();
  expect(screen.queryByText("hub")).not.toBeInTheDocument();
});

test("client path form lists hops", () => {
  render(
    <PathTrace
      devices={[
        {
          id: "dev-3",
          identity: "WS-C3850-A",
          role: "switch",
          attachments: [{ kind: "vlan", vlan: "504", label: "VLAN504 × 1" }],
        },
      ]}
      snapshotId={1}
      onResult={() => {}}
      hops={[
        { device_id: "dev-3", device_name: "WS-C3850-A", kind: "l2", iface: "VLAN504", gateway: "10.0.32.190" },
        { device_id: "dev-1", device_name: "N9K-A", kind: "l3", route_dst: "0.0.0.0/0", gateway: "10.255.63.254" },
        { device_id: "dev-0", device_name: "MTK-WAN-R1", kind: "egress", iface: "PPP-Rostelecom" },
      ]}
      status="egress"
      reason=""
    />,
  );
  expect(screen.getByText("Эмуляция клиента")).toBeInTheDocument();
  expect(screen.getByText("Показать путь")).toBeInTheDocument();
  expect(screen.getByText(/PPP-Rostelecom/)).toBeInTheDocument();
  expect(screen.getByText(/10.0.32.190/)).toBeInTheDocument();
});

const SITE_ROW = [
  ["dev-3", "WS-C3850-A", "switch", "WS-C3850"],
  ["dev-4", "WS-C3850-B", "switch", "WS-C3850"],
  ["dev-1", "N9K-A", "switch", "Nexus9000"],
  ["dev-2", "N9K-B", "switch", "Nexus9000"],
  ["dev-0", "MTK-WAN-R1", "router", "CCR2004-16G-2S+"],
  ["dev-5", "DirectCODD", "router", "CCR2004"],
  ["dev-6", "CAFAP-R1", "router", "RB4011"],
  ["dev-7", "CAFAP-R2", "router", "RB4011"],
];

const officeMesh = {
  nodes: [
    { id: "dev-6", identity: "CAFAP-R1", role: "router", model: "RB4011" },
    { id: "dev-0", identity: "MTK-WAN-R1", role: "router", model: "CCR2004-16G-2S+" },
    { id: "dev-3", identity: "WS-C3850-A", role: "switch", model: "WS-C3850" },
    { id: "dev-1", identity: "N9K-A", role: "switch", model: "Nexus9000" },
    { id: "dev-4", identity: "WS-C3850-B", role: "switch", model: "WS-C3850" },
    { id: "dev-5", identity: "DirectCODD", role: "router", model: "CCR2004" },
    { id: "dev-2", identity: "N9K-B", role: "switch", model: "Nexus9000" },
    { id: "dev-7", identity: "CAFAP-R2", role: "router", model: "RB4011" },
  ],
  links: [
    { source: "dev-3", target: "dev-1", source_name: "WS-C3850-A", target_name: "N9K-A", kind: "lacp", label: "Port-channel1 ↔ port-channel10" },
    { source: "dev-1", target: "dev-2", source_name: "N9K-A", target_name: "N9K-B", kind: "vpc", label: "vpc peer-link" },
    { source: "dev-1", target: "dev-0", source_name: "N9K-A", target_name: "MTK-WAN-R1", kind: "lacp", label: "Po3 ↔ LACP1" },
    { source: "dev-0", target: "dev-5", source_name: "MTK-WAN-R1", target_name: "DirectCODD", kind: "gre", label: "Tun04 ↔ Tun03" },
    { source: "dev-3", target: "dev-1", source_name: "WS-C3850-A", target_name: "N9K-A", kind: "svi", label: "VLAN504" },
    { source: "dev-1", target: "dev-0", source_name: "N9K-A", target_name: "MTK-WAN-R1", kind: "nexthop", label: "via 10.255.63.254" },
  ],
  topo_links: [
    {
      source: "dev-3",
      target: "dev-1",
      source_name: "WS-C3850-A",
      target_name: "N9K-A",
      kind: "lacp",
      label: "Port-channel1 ↔ port-channel10",
      a_iface: "Port-channel1",
      b_iface: "port-channel10",
    },
    {
      source: "dev-3",
      target: "dev-2",
      source_name: "WS-C3850-A",
      target_name: "N9K-B",
      kind: "lacp",
      label: "Po2 ↔ Po11",
      a_iface: "Po2",
      b_iface: "Po11",
    },
    { source: "dev-1", target: "dev-2", source_name: "N9K-A", target_name: "N9K-B", kind: "vpc", label: "vpc peer-link" },
    {
      source: "dev-1",
      target: "dev-0",
      source_name: "N9K-A",
      target_name: "MTK-WAN-R1",
      kind: "lacp",
      label: "Po3 ↔ LACP1",
      a_iface: "Po3",
      b_iface: "LACP1",
    },
    {
      source: "dev-0",
      target: "dev-5",
      source_name: "MTK-WAN-R1",
      target_name: "DirectCODD",
      kind: "gre",
      label: "Tun04 ↔ Tun03",
      a_tunnel: "Tun04",
      b_tunnel: "Tun03",
    },
    {
      source: "dev-1",
      target: "dev-0",
      source_name: "N9K-A",
      target_name: "MTK-WAN-R1",
      kind: "nexthop",
      label: "via 10.255.63.254",
      detail: "10.255.63.254",
    },
  ],
  unmatched: [],
};

function edgePair(el) {
  return `${el.getAttribute("data-source")}->${el.getAttribute("data-target")}`;
}

function hasKindPair(kind, a, b) {
  return [...document.querySelectorAll(`[data-map-edge][data-kind="${kind}"]`)].some((el) => {
    const s = el.getAttribute("data-source");
    const t = el.getAttribute("data-target");
    return (s === a && t === b) || (s === b && t === a);
  });
}

const wanHops = [
  {
    device_id: "dev-3",
    device_name: "WS-C3850-A",
    kind: "l2",
    iface: "VLAN504",
    gateway: "10.0.32.190",
    next_device: "dev-1",
  },
  {
    device_id: "dev-1",
    device_name: "N9K-A",
    kind: "l3",
    iface: "Vlan2",
    gateway: "10.255.63.254",
    next_device: "dev-0",
  },
  { device_id: "dev-0", device_name: "MTK-WAN-R1", kind: "egress", iface: "PPP-Rostelecom" },
];

const greHops = [
  {
    device_id: "dev-0",
    device_name: "MTK-WAN-R1",
    kind: "l3",
    iface: "Tun04",
    gateway: "Tun04",
    next_device: "dev-5",
  },
  { device_id: "dev-5", device_name: "DirectCODD", kind: "deliver", iface: "Tun03" },
];

test("topology lays out layers with L2 L3 GRE and no svi", () => {
  render(<SiteMap mesh={officeMesh} hops={[]} selectedId="dev-0" onSelect={() => {}} />);
  expect(screen.getByRole("heading", { name: "Топология" })).toBeInTheDocument();
  expect(screen.queryByRole("heading", { name: "Карта площадки" })).not.toBeInTheDocument();
  const boxes = [...document.querySelectorAll("[data-map-node]")];
  expect(boxes).toHaveLength(SITE_ROW.length);
  const ys = new Set(boxes.map((el) => el.getAttribute("data-map-y")));
  expect(ys.size).toBeGreaterThanOrEqual(2);
  expect(boxes.map((el) => el.getAttribute("data-map-node")).sort()).toEqual(
    SITE_ROW.map((row) => row[1]).sort(),
  );
  const kinds = [...document.querySelectorAll("[data-map-edge]")].map((el) => el.getAttribute("data-kind"));
  expect(kinds).toContain("gre");
  expect(kinds).toContain("lacp");
  expect(kinds).toContain("vpc");
  expect(kinds).toContain("nexthop");
  expect(kinds).not.toContain("svi");
  expect(kinds.every((kind) => ["gre", "lacp", "vpc", "nexthop"].includes(kind))).toBe(true);
  expect(hasKindPair("lacp", "dev-3", "dev-1")).toBe(true);
  expect(hasKindPair("lacp", "dev-3", "dev-2")).toBe(true);
  expect(hasKindPair("vpc", "dev-1", "dev-2")).toBe(true);
  expect(hasKindPair("nexthop", "dev-1", "dev-0")).toBe(true);
  const gre = document.querySelector('[data-map-edge][data-kind="gre"]');
  expect(gre.getAttribute("data-label")).toMatch(/Tun04/);
  expect(document.querySelector('[data-map-edge][data-kind="nexthop"]').getAttribute("data-label")).toMatch(
    /10\.255\.63\.254/,
  );
  expect(document.querySelectorAll('[data-map-edge][data-directed="1"]')).toHaveLength(0);
});

function chipBlob(el) {
  return `${el.textContent || ""} ${el.getAttribute("data-edge-label") || ""}`.trim();
}

test("catalog lists L2 and GRE; badges are digits; click highlights; no idle Port-channel chip", () => {
  render(<SiteMap mesh={officeMesh} hops={[]} selectedId="dev-0" onSelect={() => {}} />);
  const cat = document.querySelector("[data-link-catalog]");
  expect(cat.textContent).toMatch(/C3850/);
  expect(cat.textContent).toMatch(/N9K/);
  expect(cat.textContent).toMatch(/Po/);
  expect(cat.textContent).toMatch(/Tun/);
  expect(cat.textContent).toMatch(/C3850-A Po1 — N9K-A Po10/);
  expect(cat.textContent).not.toMatch(/Port-channel/i);
  const l2rows = [...document.querySelectorAll('[data-cat-group="l2"] [data-catalog-row]')];
  const greRows = [...document.querySelectorAll('[data-cat-group="gre"] [data-catalog-row]')];
  expect(l2rows[0].getAttribute("data-catalog-row")).toBe("1");
  expect(Number(greRows[0].getAttribute("data-catalog-row"))).toBe(l2rows.length + 1);
  expect(l2rows[0].textContent).toMatch(/C3850-A Po1 — N9K-A Po10/);
  const badges = [...document.querySelectorAll("[data-edge-badge]")];
  expect(badges.length).toBeGreaterThanOrEqual(4);
  expect(badges.every((el) => /^\d+$/.test(el.getAttribute("data-edge-badge") || ""))).toBe(true);
  expect(badges.every((el) => /^\d+$/.test((el.textContent || "").trim()))).toBe(true);
  expect(document.querySelector('[data-map-edge][data-kind="nexthop"]').getAttribute("data-badge")).toBe("");
  const idleChips = [...document.querySelectorAll("[data-edge-label]")];
  expect(idleChips).toHaveLength(0);
  expect(idleChips.some((el) => /Port-channel/i.test(chipBlob(el)))).toBe(false);
  const row = [...document.querySelectorAll("[data-catalog-row]")].find((el) =>
    /C3850-A Po1 — N9K-A Po10/.test(el.textContent || ""),
  );
  fireEvent.click(row);
  expect(row.getAttribute("data-picked")).toBe("1");
  expect(document.querySelector('[data-map-edge][data-picked="1"]')).toBeTruthy();
});

test("path hop chip stays visible on directed edges", () => {
  render(<SiteMap mesh={officeMesh} selectedId="dev-3" onSelect={() => {}} hops={wanHops} />);
  const directed = [...document.querySelectorAll('[data-map-edge][data-directed="1"]')];
  expect(directed).toHaveLength(2);
  const chips = [...document.querySelectorAll("[data-edge-label]")];
  expect(chips.some((el) => /VLAN504/.test(chipBlob(el)))).toBe(true);
  expect(chips.every((el) => !/Port-channel/i.test(chipBlob(el)))).toBe(true);
  expect(document.querySelector('[data-catalog-row][data-on-path="1"]')).toBeTruthy();
  expect(document.querySelector("[data-link-catalog]").textContent).toMatch(/путь/);
});

test("unknown switch and router use distinct layers", () => {
  render(
    <SiteMap
      mesh={{
        nodes: [
          { id: "dev-x", identity: "SW-UNKNOWN", role: "switch", model: "C9K" },
          { id: "dev-y", identity: "RTR-UNKNOWN", role: "router", model: "CCR" },
        ],
        links: [],
        topo_links: [],
        unmatched: [],
      }}
      hops={[]}
      selectedId="dev-x"
      onSelect={() => {}}
    />,
  );
  const boxes = [...document.querySelectorAll("[data-map-node]")];
  expect(new Set(boxes.map((el) => el.getAttribute("data-map-y"))).size).toBeGreaterThanOrEqual(2);
});

test("path hops mark directed edges", () => {
  render(<SiteMap mesh={officeMesh} selectedId="dev-3" onSelect={() => {}} hops={wanHops} />);
  const directed = [...document.querySelectorAll('[data-map-edge][data-directed="1"]')];
  expect(directed).toHaveLength(2);
  expect(directed.map(edgePair)).toEqual(["dev-3->dev-1", "dev-1->dev-0"]);
  expect(document.querySelector('[data-map-edge][data-kind="vpc"]').getAttribute("data-directed")).toBe("0");
});

test("second path replaces first arrows", () => {
  const { rerender } = render(
    <SiteMap mesh={officeMesh} selectedId="dev-3" onSelect={() => {}} hops={wanHops} />,
  );
  expect([...document.querySelectorAll('[data-map-edge][data-directed="1"]')].map(edgePair)).toEqual([
    "dev-3->dev-1",
    "dev-1->dev-0",
  ]);
  rerender(<SiteMap mesh={officeMesh} selectedId="dev-0" onSelect={() => {}} hops={greHops} />);
  const directed = [...document.querySelectorAll('[data-map-edge][data-directed="1"]')];
  expect(directed.map(edgePair)).toEqual(["dev-0->dev-5"]);
  expect(document.querySelector('[data-map-edge][data-kind="gre"]').getAttribute("data-directed")).toBe("1");
  expect(
    [...document.querySelectorAll("[data-edge-label]")].some((el) =>
      /Tun/.test(`${el.textContent || ""} ${el.getAttribute("data-edge-label") || ""}`),
    ),
  ).toBe(true);
  expect(
    [...document.querySelectorAll('[data-map-edge][data-directed="1"]')].some((el) => edgePair(el) === "dev-3->dev-1"),
  ).toBe(false);
});

function MapAndSchematic() {
  const [sel, setSel] = useState("dev-0");
  const graphs = { "dev-0": hubGraph, "dev-1": neighborGraph };
  return (
    <>
      <SiteMap mesh={twoNodeMesh} hops={[]} selectedId={sel} onSelect={setSel} />
      <TopologyCanvas selectedRouteId={null} graph={graphs[sel]} />
    </>
  );
}

test("selecting a map node shows that schematic title", () => {
  render(<MapAndSchematic />);
  expect(document.querySelectorAll(".schematic")).toHaveLength(1);
  expect(document.querySelector(".schematic-kicker strong")).toHaveTextContent("MTK-WAN-R1");
  fireEvent.click(document.querySelector('[data-map-node="CAFAP-R1"]'));
  expect(document.querySelector(".schematic-kicker strong")).toHaveTextContent("CAFAP-R1");
  expect(document.querySelectorAll(".schematic")).toHaveLength(1);
  expect(document.querySelector('.schematic[data-device="dev-1"]')).toHaveTextContent("CAFAP-R1");
});
