from app.infer.graph import build_graph
from app.parsers.rsc import parse_rsc


def test_graph_contains_core_nodes(sample_rsc: str) -> None:
    graph = build_graph(parse_rsc(sample_rsc))
    ids = {n["id"] for n in graph["nodes"]}
    assert "router" in ids
    assert "iface:PPP-Rostelecom" in ids
    assert "iface:VLAN2" in ids
    assert "iface:Tun01" in ids
    assert "iface:Tun04" in ids
    assert "iface:LACP1" in ids
    assert "peer:93.94.178.33" in ids
    assert any(n["id"].startswith("prefix:10.255.63.0") for n in graph["nodes"])
    assert any(e["kind"] == "tunnel" for e in graph["edges"])
    assert any(e["kind"] == "nat" and e["direction"] == "egress" for e in graph["edges"])
    assert any(e["kind"] == "nat" and e["direction"] == "ingress" for e in graph["edges"])
    assert any(e["kind"] == "default" for e in graph["edges"])
    assert graph["router"]["name"] == "MTK-WAN-R1"
    assert graph["stats"]["routes_enabled"] >= 3
    visible = [n for n in graph["nodes"] if n["position"]["x"] > -1000]
    assert len(visible) <= 22
    ether_cards = [n for n in visible if n["data"].get("kind") == "ethernet"]
    assert all(n["data"].get("zone") == "WAN" for n in ether_cards)
    router = next(n for n in graph["nodes"] if n["id"] == "router")
    port_names = [p["name"] for p in router["data"]["ports"]]
    assert port_names[:16] == [f"ether{i}" for i in range(1, 17)]
    assert "sfp-sfpplus1" in port_names


def test_id_prefix_namespaces_nodes(sample_rsc: str) -> None:
    cfg = parse_rsc(sample_rsc)
    plain = {n["id"] for n in build_graph(cfg)["nodes"]}
    assert "router" in plain
    assert "iface:Tun01" in plain
    namespaced = {n["id"] for n in build_graph(cfg, id_prefix="dev-0")["nodes"]}
    assert "dev-0:router" in namespaced
    assert "dev-0:iface:Tun01" in namespaced
    assert "router" not in namespaced
    assert "iface:Tun01" not in namespaced


def test_small_box_does_not_invent_ccr_jacks() -> None:
    cfg = parse_rsc(
        """
# model = hEX
/interface ethernet
set [ find default-name=ether1 ] comment=wan
set [ find default-name=ether5 ] comment=lan
/interface list
add name=WAN
/interface list member
add interface=ether1 list=WAN
/system identity
set name=TINY
"""
    )
    graph = build_graph(cfg)
    router = next(n for n in graph["nodes"] if n["id"] == "router")
    names = [p["name"] for p in router["data"]["ports"]]
    assert names == ["ether1", "ether5"]
    ids = {n["id"] for n in graph["nodes"]}
    assert "iface:ether1" in ids
    assert "iface:ether16" not in ids
