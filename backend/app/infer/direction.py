"""Infer traffic direction from static RouterOS config."""

from __future__ import annotations

import ipaddress
from typing import Any

from app.parsers.rsc import ParsedConfig


def _ip_network(value: str) -> ipaddress.IPv4Network | None:
    if not value:
        return None
    try:
        if "/" in value:
            return ipaddress.ip_network(value, strict=False)
        return ipaddress.ip_network(f"{value}/32", strict=False)
    except ValueError:
        return None


def _ip_address(value: str) -> ipaddress.IPv4Address | None:
    if not value:
        return None
    try:
        return ipaddress.ip_address(value.split("/")[0])
    except ValueError:
        return None


def zone_for_interface(cfg: ParsedConfig, name: str) -> str:
    for member in cfg.list_members:
        if member.get("interface") == name and not member.get("disabled"):
            lst = (member.get("list") or "").upper()
            if lst == "WAN":
                return "WAN"
            if lst.startswith("VPN"):
                return "VPN"
            if lst in {"LAN", "DMZ"}:
                return lst
    iface = cfg.iface_by_name(name)
    if not iface:
        return "UNKNOWN"
    kind = iface.get("kind")
    if "VPN" in name.upper():
        return "VPN"
    if kind == "pppoe":
        return "WAN"
    if kind == "gre":
        return "VPN"
    if kind in {"vlan", "bridge", "ethernet", "bonding"}:
        return "LAN"
    return "UNKNOWN"


def resolve_gateway_interface(cfg: ParsedConfig, gateway: str) -> str | None:
    if not gateway:
        return None
    if cfg.iface_by_name(gateway):
        return gateway
    hop = _ip_address(gateway)
    if hop is None:
        return None
    for addr in cfg.addresses:
        if addr.get("disabled"):
            continue
        net = _ip_network(addr.get("address") or "")
        if net and hop in net:
            return addr.get("interface")
    for local in cfg.ppp_locals:
        addr = _ip_address(local)
        if addr and hop in ipaddress.ip_network(f"{addr}/24", strict=False):
            return "VPN-bridge"
    return None


def infer_route_direction(cfg: ParsedConfig, route: dict[str, Any]) -> str:
    if route.get("disabled"):
        return "disabled"
    dst = route.get("dst") or ""
    table = route.get("routing_table") or "main"
    gateway = route.get("gateway") or ""
    gw_iface = resolve_gateway_interface(cfg, gateway)
    zone = zone_for_interface(cfg, gw_iface) if gw_iface else "UNKNOWN"

    if table != "main":
        return "policy"
    if dst in {"0.0.0.0/0", "0.0.0.0"}:
        return "egress"
    if gw_iface:
        iface = cfg.iface_by_name(gw_iface)
        if iface and iface.get("kind") == "gre":
            return "tunnel"
        if zone == "VPN":
            return "tunnel"
        if zone == "WAN":
            return "egress"
    for addr in cfg.addresses:
        if addr.get("disabled"):
            continue
        if (addr.get("network") and dst.startswith(addr["network"])) or dst == addr.get("address"):
            if (addr.get("interface") or "") == (gw_iface or addr.get("interface")):
                return "local"
        net = _ip_network(addr.get("address") or "")
        route_net = _ip_network(dst)
        if net and route_net and route_net.subnet_of(net) and addr.get("interface") == gw_iface:
            return "local"
    if zone == "LAN":
        return "local"
    return "egress"


def infer_nat_direction(rule: dict[str, Any]) -> str | None:
    if rule.get("disabled"):
        return None
    action = rule.get("action")
    chain = rule.get("chain")
    if chain == "srcnat" and action in {"src-nat", "masquerade"}:
        return "egress"
    if chain == "dstnat" and action == "dst-nat":
        return "ingress"
    return None
