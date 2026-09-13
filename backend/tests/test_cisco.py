from pathlib import Path

from app.infer.graph import build_graph
from app.parsers.cisco import detect_format, parse_cisco, redact_cisco

FIXTURES = Path(__file__).parent / "fixtures"


def test_detect_cisco_and_rsc(sample_rsc: str) -> None:
    cisco = (FIXTURES / "n9k_a.conf").read_text(encoding="utf-8")
    assert detect_format(cisco) == "cisco"
    assert detect_format(sample_rsc) == "rsc"
    assert detect_format("hello") == "unknown"


def test_parse_nexus_fixture() -> None:
    cfg = parse_cisco((FIXTURES / "n9k_a.conf").read_text(encoding="utf-8"))
    assert cfg.identity == "N9K-A"
    assert cfg.role == "switch"
    assert cfg.vendor == "cisco"
    svi9 = cfg.iface_by_name("Vlan9")
    svi504 = cfg.iface_by_name("Vlan504")
    assert svi9 and svi9["kind"] == "vlan"
    assert svi504 and svi504["vlan_id"] == "504"
    addrs = {a["address"] for a in cfg.addresses}
    assert "10.255.63.241/28" in addrs
    assert "10.0.32.189/26" in addrs
    hsrp = next(h for h in cfg.hsrp if h["vlan"] == "504")
    assert hsrp["vip"] == "10.0.32.190"
    assert hsrp["priority"] == 120
    defaults = [r for r in cfg.routes if r["dst"] in {"0.0.0.0/0", "0.0.0.0"}]
    assert any(r["gateway"] == "10.255.63.254" for r in defaults)
    assert not any(r["gateway"] == "10.255.63.62" for r in cfg.routes)
    po3 = cfg.iface_by_name("port-channel3")
    assert po3 and po3["comment"] == "LACP-MTK-WAN-R1"
    assert po3["vpc"] == "3"
    assert "Ethernet1/3" in (po3.get("slaves") or "")


def test_parse_catalyst_ios_mask() -> None:
    cfg = parse_cisco((FIXTURES / "c3850_a.conf").read_text(encoding="utf-8"))
    assert cfg.identity == "WS-C3850-A"
    assert cfg.model == "WS-C3850-48U"
    addr = next(a for a in cfg.addresses if a["interface"] == "Vlan9")
    assert addr["address"] == "10.255.63.243/28"
    assert any(r["dst"] == "0.0.0.0/0" and r["gateway"] == "10.255.63.254" for r in cfg.routes)
    assert not any(r["gateway"] == "10.255.63.62" for r in cfg.routes)
    assert any(p["vlan"] == "504" for p in cfg.access_ports)
    po = cfg.iface_by_name("Port-channel1")
    assert po and po["kind"] == "bonding"


def test_cisco_secrets_redacted() -> None:
    raw = (FIXTURES / "n9k_a.conf").read_text(encoding="utf-8")
    red = redact_cisco(raw)
    assert "super-hsrp-secret" not in red
    assert "$5$FAKECISCOHASH" not in red
    assert "REDACTED" in red
    cfg = parse_cisco(raw)
    dumped = str(cfg)
    assert "super-hsrp-secret" not in dumped
    assert "$5$FAKECISCOHASH" not in dumped


def test_switch_schematic_groups_access_not_48_jacks() -> None:
    cfg = parse_cisco((FIXTURES / "c3850_a.conf").read_text(encoding="utf-8"))
    graph = build_graph(cfg)
    router = next(n for n in graph["nodes"] if n["id"] == "router")
    port_names = [p["name"] for p in router["data"]["ports"]]
    assert any("Po" in p or "port-channel" in p.lower() or p.lower().startswith("po") for p in port_names)
    assert not any("1/0/1" in p for p in port_names)
    ids = {n["id"] for n in graph["nodes"]}
    assert "iface:Vlan9" in ids
    assert "iface:VLAN504" in ids
    group = next(n for n in graph["nodes"] if n["id"] == "iface:VLAN504")
    assert any("access ports" in line for line in group["data"]["lines"])
    assert "GigabitEthernet1/0/2" not in ids
