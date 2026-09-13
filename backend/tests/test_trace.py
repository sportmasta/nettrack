from pathlib import Path

from app.infer.site import build_site_graph
from app.infer.trace import trace_path
from app.parsers.cisco import parse_device
from app.parsers.rsc import parse_rsc

FIXTURES = Path(__file__).parent / "fixtures"


def _office(sample_rsc: str):
    return [
        (parse_rsc(sample_rsc), "sample.rsc"),
        (parse_device((FIXTURES / "n9k_a.conf").read_text(encoding="utf-8")), "n9k_a.conf"),
        (parse_device((FIXTURES / "n9k_b.conf").read_text(encoding="utf-8")), "n9k_b.conf"),
        (parse_device((FIXTURES / "c3850_a.conf").read_text(encoding="utf-8")), "c3850_a.conf"),
        (parse_device((FIXTURES / "c3850_b.conf").read_text(encoding="utf-8")), "c3850_b.conf"),
        (parse_rsc((FIXTURES / "direct.rsc").read_text(encoding="utf-8")), "direct.rsc"),
    ]


def test_trace_vlan504_to_internet(sample_rsc: str) -> None:
    roster = _office(sample_rsc)
    graph = build_site_graph(roster)
    c3850 = next(d for d in graph["devices"] if d["identity"] == "WS-C3850-A")
    result = trace_path(roster, {"device_id": c3850["id"], "vlan": "504"}, "8.8.8.8", mesh=graph["mesh"])
    names = [h["device_name"] for h in result["hops"]]
    kinds = [h["kind"] for h in result["hops"]]
    assert names[0] == "WS-C3850-A"
    assert kinds[0] == "l2"
    assert result["hops"][0]["gateway"] == "10.0.32.190"
    assert "N9K-A" in names
    assert any(h["kind"] == "l3" and h["gateway"] == "10.255.63.254" for h in result["hops"])
    assert names[-1] == "MTK-WAN-R1"
    assert kinds[-1] == "egress"
    assert result["status"] == "egress"
    assert any("PPP" in (h.get("iface") or "") for h in result["hops"])


def test_trace_vlan504_to_directcodd_lan(sample_rsc: str) -> None:
    roster = _office(sample_rsc)
    graph = build_site_graph(roster)
    c3850 = next(d for d in graph["devices"] if d["identity"] == "WS-C3850-A")
    result = trace_path(
        roster, {"device_id": c3850["id"], "vlan": 504}, "10.38.0.40", mesh=graph["mesh"]
    )
    names = [h["device_name"] for h in result["hops"]]
    kinds = [h["kind"] for h in result["hops"]]
    assert names[0] == "WS-C3850-A" and kinds[0] == "l2"
    assert "N9K-A" in names
    assert "MTK-WAN-R1" in names
    assert names[-1] == "DirectCODD"
    assert kinds[-1] == "deliver"
    assert result["status"] == "deliver"
    gre = next(h for h in result["hops"] if h["device_name"] == "MTK-WAN-R1" and h["kind"] == "l3")
    assert gre["iface"] == "Tun04" or gre["gateway"] == "Tun04"
