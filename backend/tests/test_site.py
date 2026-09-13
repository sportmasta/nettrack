from pathlib import Path

from app.infer.site import build_site_graph, build_topo_links, device_role
from app.parsers.cisco import parse_device
from app.parsers.rsc import parse_rsc

FIXTURES = Path(__file__).parent / "fixtures"


def _cfg(name: str):
    text = (FIXTURES / name).read_text(encoding="utf-8")
    if name.endswith(".conf"):
        return parse_device(text)
    return parse_rsc(text)


def test_neighbor_attaches_without_dropping_first(sample_rsc: str) -> None:
    hub = parse_rsc(sample_rsc)
    neighbor = parse_rsc(
        """
# model = RB4011iGS+
/interface gre
add local-address=93.94.178.33 name=gre-hub remote-address=90.188.224.225
/ip address
add address=10.20.0.1/24 interface=VLAN10 network=10.20.0.0
/system identity
set name=CAFAP-R1
"""
    )
    graph = build_site_graph([(hub, "hub.rsc"), (neighbor, "cafap.rsc")])
    ids = {n["id"] for n in graph["nodes"]}
    assert "iface:PPP-Rostelecom" in ids
    assert "iface:Tun01" in ids
    assert graph["router"]["name"] == "MTK-WAN-R1"
    assert graph["devices"][0]["role"] == "router"
    assert graph["devices"][1]["role"] == "router"
    assert graph["devices"][1]["identity"] == "CAFAP-R1"
    assert len(graph["neighbors"]) == 1
    nb = graph["neighbors"][0]
    assert nb["identity"] == "CAFAP-R1"
    mesh_links = graph["mesh"]["links"]
    gre = [link for link in mesh_links if link["kind"] == "gre"]
    assert len(gre) == 1
    assert gre[0]["source_name"] == "MTK-WAN-R1"
    assert gre[0]["target_name"] == "CAFAP-R1"


def test_full_mesh_between_all_devices() -> None:
    hub = parse_rsc(
        """
# model = CCR2004-16G-2S+
/interface gre
add comment="CAFAP R1" local-address=90.188.224.225 name=Tun01 remote-address=93.94.178.33
add comment=toDirect local-address=90.188.224.225 name=Tun04 remote-address=95.189.32.202
add comment=home local-address=90.188.224.225 name=Tun10 remote-address=5.183.147.235
/system identity
set name=MTK-WAN-R1
"""
    )
    cafap = parse_rsc(
        """
# model = CCR2004-16G-2S+
/interface gre
add local-address=93.94.178.33 name=Tun02 remote-address=90.188.224.225
add local-address=93.94.178.33 name=Tun03 remote-address=95.189.32.202
/system identity
set name=CAFAP-R1
"""
    )
    direct = parse_rsc(
        """
# model = CCR2004-16G-2S+
/interface gre
add local-address=95.189.32.202 name=Tun01 remote-address=93.94.178.33
add local-address=95.189.32.202 name=Tun03 remote-address=90.188.224.225
/system identity
set name=DirectCODD
"""
    )
    graph = build_site_graph([(hub, "hub.rsc"), (cafap, "cafap.rsc"), (direct, "direct.rsc")])
    pairs = {(link["source_name"], link["target_name"]) for link in graph["mesh"]["links"] if link["kind"] == "gre"}
    assert ("MTK-WAN-R1", "CAFAP-R1") in pairs
    assert ("MTK-WAN-R1", "DirectCODD") in pairs
    assert ("CAFAP-R1", "DirectCODD") in pairs
    assert len([link for link in graph["mesh"]["links"] if link["kind"] == "gre"]) == 3
    assert any(u["name"] == "Tun10" for u in graph["mesh"]["unmatched"])
    assert len(graph["device_graphs"]) == 3
    assert all(item["role"] in {"router", "switch"} for item in graph["devices"])


def test_device_graphs_for_each_export(sample_rsc: str) -> None:
    hub = parse_rsc(sample_rsc)
    neighbor = parse_rsc((FIXTURES / "neighbor.rsc").read_text(encoding="utf-8"))
    extra = parse_rsc(
        """
# model = CCR2004-16G-2S+
/interface gre
add local-address=95.189.32.202 name=Tun03 remote-address=90.188.224.225
/system identity
set name=DirectCODD
"""
    )
    graph = build_site_graph([(hub, "hub.rsc"), (neighbor, "neighbor.rsc"), (extra, "direct.rsc")])
    assert len(graph["device_graphs"]) == 3
    assert [g["device_id"] for g in graph["device_graphs"]] == ["dev-0", "dev-1", "dev-2"]
    assert graph["device_graphs"][0]["router"]["name"] == "MTK-WAN-R1"
    assert graph["device_graphs"][0]["filename"] == "hub.rsc"
    assert graph["device_graphs"][0]["role"] == "router"
    nb = graph["device_graphs"][1]
    assert nb["role"] == "router"
    assert nb["filename"] == "neighbor.rsc"
    assert nb["router"]["name"] == "CAFAP-R1"
    ids = {n["id"] for n in nb["nodes"]}
    assert "dev-1:router" in ids
    assert "dev-1:iface:VLAN10" in ids
    assert "dev-1:iface:gre-hub" in ids
    assert any(n["id"] == "dev-1:prefix:10.20.0.0/24" for n in nb["nodes"])
    assert all(r["device_id"] == "dev-1" and r["device_name"] == "CAFAP-R1" for r in nb["routes"])
    hub_ids = {n["id"] for n in graph["nodes"]}
    assert "iface:PPP-Rostelecom" in hub_ids
    assert graph["devices"][1]["id"] == "dev-1"


def test_gre_pair_advertises_and_receives(sample_rsc: str) -> None:
    hub = parse_rsc(
        sample_rsc
        + """
/ip route
add dst-address=10.20.0.0/24 gateway=Tun01
"""
    )
    neighbor = parse_rsc((FIXTURES / "neighbor.rsc").read_text(encoding="utf-8"))
    graph = build_site_graph([(hub, "hub.rsc"), (neighbor, "neighbor.rsc")])
    gre = [link for link in graph["mesh"]["links"] if link["kind"] == "gre"]
    assert len(gre) == 1
    link = gre[0]
    advertised = {(row["dst"], row["from"], row["to"]) for row in link["advertised"]}
    received = {(row["dst"], row["from"], row["to"]) for row in link["received"]}
    assert ("10.255.63.0/26", "MTK-WAN-R1", "CAFAP-R1") in advertised
    assert ("10.20.0.0/24", "CAFAP-R1", "MTK-WAN-R1") in advertised
    assert ("10.20.0.0/24", "CAFAP-R1", "MTK-WAN-R1") in received
    assert ("10.255.63.0/26", "MTK-WAN-R1", "CAFAP-R1") in received
    assert any(row["dst"] == "192.168.50.0/24" and row["origin"] == "static" for row in link["forwarded"])
    assert graph["exchange"]
    assert any(row["role"] == "advertised" and row["dst"] == "10.255.63.0/26" for row in graph["exchange"])


def test_unmatched_tunnel_has_no_fake_exchange(sample_rsc: str) -> None:
    hub = parse_rsc(sample_rsc)
    neighbor = parse_rsc((FIXTURES / "neighbor.rsc").read_text(encoding="utf-8"))
    graph = build_site_graph([(hub, "hub.rsc"), (neighbor, "neighbor.rsc")])
    unmatched = {u["name"] for u in graph["mesh"]["unmatched"]}
    assert "Tun04" in unmatched
    assert all("Tun04" not in (link.get("label") or "") for link in graph["mesh"]["links"])
    assert not any(row.get("via_tunnel") == "Tun04" or row.get("peer_tunnel") == "Tun04" for row in graph["exchange"])
    for tun in graph["mesh"]["unmatched"]:
        assert tun["advertised"] == []
        assert tun["received"] == []
        assert tun["forwarded"] == []


def _office_roster(sample_rsc: str):
    return [
        (parse_rsc(sample_rsc), "sample.rsc"),
        (_cfg("n9k_a.conf"), "n9k_a.conf"),
        (_cfg("n9k_b.conf"), "n9k_b.conf"),
        (_cfg("c3850_a.conf"), "c3850_a.conf"),
        (_cfg("c3850_b.conf"), "c3850_b.conf"),
        (_cfg("direct.rsc"), "direct.rsc"),
    ]


def _pair_kind(graph, a: str, b: str, kind: str) -> bool:
    names = {a, b}
    return any(
        {link["source_name"], link["target_name"]} == names and link["kind"] == kind
        for link in graph["mesh"]["links"]
    )


def test_mesh_lacp_vpc_svi(sample_rsc: str) -> None:
    graph = build_site_graph(_office_roster(sample_rsc))
    kinds = {link["kind"] for link in graph["mesh"]["links"]}
    assert {"gre", "lacp", "vpc", "svi", "nexthop"} <= kinds
    assert _pair_kind(graph, "N9K-A", "MTK-WAN-R1", "lacp")
    assert _pair_kind(graph, "N9K-B", "MTK-WAN-R1", "lacp")
    assert _pair_kind(graph, "N9K-A", "WS-C3850-A", "lacp")
    assert _pair_kind(graph, "N9K-B", "WS-C3850-B", "lacp")
    assert _pair_kind(graph, "N9K-A", "N9K-B", "vpc")
    assert _pair_kind(graph, "N9K-A", "MTK-WAN-R1", "svi")
    assert _pair_kind(graph, "N9K-A", "MTK-WAN-R1", "nexthop")
    roles = {d["identity"]: d["role"] for d in graph["devices"]}
    assert roles["MTK-WAN-R1"] == "router"
    assert roles["N9K-A"] == "switch"
    assert roles["WS-C3850-A"] == "switch"
    assert not any(d["role"] in {"hub", "peer", "neighbor"} for d in graph["devices"])
    assert device_role(_cfg("n9k_a.conf")) == "switch"


def test_topo_links_kinds_and_dedup() -> None:
    links = [
        {
            "source": "dev-3",
            "target": "dev-1",
            "source_name": "WS-C3850-A",
            "target_name": "N9K-A",
            "kind": "lacp",
            "label": "Po1 ↔ Po10",
            "a_iface": "Po1",
            "b_iface": "Po10",
        },
        {
            "source": "dev-1",
            "target": "dev-3",
            "source_name": "N9K-A",
            "target_name": "WS-C3850-A",
            "kind": "lacp",
            "label": "Po10 ↔ Po1",
            "a_iface": "Po10",
            "b_iface": "Po1",
        },
        {
            "source": "dev-3",
            "target": "dev-2",
            "source_name": "WS-C3850-A",
            "target_name": "N9K-B",
            "kind": "lacp",
            "label": "Po2 ↔ Po11",
            "a_iface": "Po2",
            "b_iface": "Po11",
        },
        {
            "source": "dev-1",
            "target": "dev-2",
            "source_name": "N9K-A",
            "target_name": "N9K-B",
            "kind": "vpc",
            "label": "vpc peer-link",
        },
        {
            "source": "dev-0",
            "target": "dev-5",
            "source_name": "MTK-WAN-R1",
            "target_name": "DirectCODD",
            "kind": "gre",
            "label": "Tun04 ↔ Tun03",
            "a_tunnel": "Tun04",
            "b_tunnel": "Tun03",
            "advertised": [{"dst": "10.255.63.0/26", "from": "MTK-WAN-R1", "to": "DirectCODD"}],
        },
        {
            "source": "dev-0",
            "target": "dev-5",
            "source_name": "MTK-WAN-R1",
            "target_name": "DirectCODD",
            "kind": "gre",
            "label": "Tun01 ↔ Tun02",
            "a_tunnel": "Tun01",
            "b_tunnel": "Tun02",
        },
        {
            "source": "dev-0",
            "target": "dev-1",
            "source_name": "MTK-WAN-R1",
            "target_name": "N9K-A",
            "kind": "svi",
            "label": "VLAN2 10.255.63.0/26",
        },
        {
            "source": "dev-1",
            "target": "dev-0",
            "source_name": "N9K-A",
            "target_name": "MTK-WAN-R1",
            "kind": "nexthop",
            "label": "via 10.255.63.254",
            "detail": "10.255.63.254",
        },
        {
            "source": "dev-1",
            "target": "dev-0",
            "source_name": "N9K-A",
            "target_name": "MTK-WAN-R1",
            "kind": "nexthop",
            "label": "via 10.255.63.254",
            "detail": "10.255.63.254",
        },
    ]
    mapped = build_topo_links(links)
    kinds = {link["kind"] for link in mapped}
    assert kinds == {"gre", "lacp", "vpc", "nexthop"}
    assert "svi" not in kinds
    lacp = [link for link in mapped if link["kind"] == "lacp"]
    assert len(lacp) == 2
    peers = {frozenset({link["source"], link["target"]}) for link in lacp}
    assert peers == {frozenset({"dev-3", "dev-1"}), frozenset({"dev-3", "dev-2"})}
    gre = [link for link in mapped if link["kind"] == "gre"]
    assert len(gre) == 2
    assert {link["label"] for link in gre} == {"Tun04 ↔ Tun03", "Tun01 ↔ Tun02"}
    assert next(link for link in gre if "Tun04" in link["label"])["advertised"][0]["dst"] == "10.255.63.0/26"
    nh = [link for link in mapped if link["kind"] == "nexthop"]
    assert len(nh) == 1
    assert nh[0]["label"] == "via 10.255.63.254"
    assert nh[0]["source"] == "dev-1" and nh[0]["target"] == "dev-0"


def _topo_key(link: dict) -> tuple:
    kind = link["kind"]
    if kind == "nexthop":
        return (link["source"], link["target"], kind, link.get("detail") or link.get("label"))
    a = (link.get("a_iface") or link.get("a_tunnel") or "").lower()
    b = (link.get("b_iface") or link.get("b_tunnel") or "").lower()
    return (frozenset({link["source"], link["target"]}), kind, tuple(sorted((a, b))))


def test_office_topo_links_keep_full_mesh(sample_rsc: str) -> None:
    graph = build_site_graph(_office_roster(sample_rsc))
    topo = graph["mesh"]["topo_links"]
    kinds = {link["kind"] for link in topo}
    assert kinds <= {"gre", "lacp", "vpc", "nexthop"}
    assert "svi" not in kinds
    assert "nexthop" in kinds
    assert "gre" in kinds
    assert "lacp" in kinds
    assert "vpc" in kinds
    assert any(link["kind"] == "svi" for link in graph["mesh"]["links"])
    assert any(link["kind"] == "nexthop" for link in graph["mesh"]["links"])
    assert any("Tun" in (link.get("label") or "") for link in topo if link["kind"] == "gre")
    assert any(
        {link["source_name"], link["target_name"]} == {"N9K-A", "N9K-B"} and link["kind"] == "vpc" for link in topo
    )
    assert any(
        {link["source_name"], link["target_name"]} == {"WS-C3850-A", "N9K-A"} and link["kind"] == "lacp" for link in topo
    )
    assert any(
        link["kind"] == "nexthop" and "10.255.63.254" in (link.get("label") or "") for link in topo
    )
    keys = [_topo_key(link) for link in topo]
    assert len(keys) == len(set(keys))
