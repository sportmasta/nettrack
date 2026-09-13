from app.infer.direction import infer_nat_direction, infer_route_direction, zone_for_interface
from app.parsers.rsc import parse_rsc


def test_zones_and_directions(sample_rsc: str) -> None:
    cfg = parse_rsc(sample_rsc)
    assert zone_for_interface(cfg, "PPP-Rostelecom") == "WAN"
    assert zone_for_interface(cfg, "VLAN2") == "LAN"
    assert zone_for_interface(cfg, "Tun01") == "VPN"

    by_gw = {r["gateway"]: r for r in cfg.routes if not r.get("disabled")}
    assert infer_route_direction(cfg, by_gw["PPP-Rostelecom"]) == "egress"
    tun_default = next(r for r in cfg.routes if r["gateway"] == "Tun04" and r["dst"] == "0.0.0.0/0")
    assert infer_route_direction(cfg, tun_default) == "policy"
    tun_prefix = next(r for r in cfg.routes if r["dst"] == "10.38.0.0/16")
    assert infer_route_direction(cfg, tun_prefix) == "tunnel"

    srcnat = next(n for n in cfg.nat if n["action"] == "src-nat")
    dstnat = next(n for n in cfg.nat if n["action"] == "dst-nat")
    assert infer_nat_direction(srcnat) == "egress"
    assert infer_nat_direction(dstnat) == "ingress"
