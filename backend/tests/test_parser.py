from app.parsers.rsc import parse_rsc


def test_parse_sample_topology(sample_rsc: str) -> None:
    cfg = parse_rsc(sample_rsc)
    assert cfg.identity == "MTK-WAN-R1"
    assert cfg.model == "CCR2004-16G-2S+"
    assert cfg.iface_by_name("Tun01")["remote_address"] == "93.94.178.33"
    assert cfg.iface_by_name("Tun04")["kind"] == "gre"
    assert cfg.iface_by_name("VLAN2")["vlan_id"] == "2"
    assert cfg.iface_by_name("LACP1")["slaves"] == "sfp-sfpplus1,sfp-sfpplus2"
    assert cfg.iface_by_name("PPP-Rostelecom")["add_default_route"] is True
    assert cfg.iface_by_name("PPP-Rostelecom")["kind"] == "pppoe"
    assert any(a["address"] == "10.255.63.62/26" for a in cfg.addresses)
    tables = {t["name"] for t in cfg.routing_tables}
    assert "via-direct" in tables


def test_secrets_are_redacted(sample_rsc: str) -> None:
    cfg = parse_rsc(sample_rsc)
    ppp = cfg.iface_by_name("PPP-Rostelecom")
    assert ppp is not None
    dumped = str(cfg)
    assert "super-secret" not in dumped
    assert "secret-user" not in dumped


def test_pppoe_synthesizes_default_route(sample_rsc: str) -> None:
    cfg = parse_rsc(sample_rsc)
    defaults = [r for r in cfg.routes if r["dst"] == "0.0.0.0/0"]
    assert any(r["gateway"] == "PPP-Rostelecom" and r["synthetic"] for r in defaults)
    assert any(r["gateway"] == "Tun04" and r["routing_table"] == "via-direct" for r in defaults)


def test_parse_real_ccr_export() -> None:
    from pathlib import Path

    path = Path(__file__).resolve().parents[2] / "config" / "ccr2004.rsc"
    if not path.is_file():
        return
    cfg = parse_rsc(path.read_text(encoding="utf-8", errors="replace"))
    assert cfg.identity == "MTK-WAN-R1"
    assert cfg.iface_by_name("PPP-Rostelecom")
    assert cfg.iface_by_name("Tun01")
    assert cfg.iface_by_name("Tun04")
    assert len(cfg.routes) > 50
    assert any(r["dst"] == "0.0.0.0/0" and r["gateway"] == "PPP-Rostelecom" for r in cfg.routes)
