"""Hop-by-hop client path from a VLAN/iface to a destination IP."""

from __future__ import annotations

import ipaddress
from typing import Any

from app.infer.direction import resolve_gateway_interface
from app.infer.graph import _prefix_from_address
from app.infer.site import Roster, build_mesh, owned_ips
from app.parsers.rsc import ParsedConfig

MAX_HOPS = 16


def _ip(value: str) -> ipaddress.IPv4Address | None:
    if not value:
        return None
    try:
        return ipaddress.ip_address(str(value).split("/", 1)[0])
    except ValueError:
        return None


def _net(value: str) -> ipaddress.IPv4Network | None:
    if not value:
        return None
    try:
        if "/" in value:
            return ipaddress.ip_network(value, strict=False)
        return ipaddress.ip_network(f"{value}/32", strict=False)
    except ValueError:
        return None


def _is_mgmt(route: dict[str, Any]) -> bool:
    vrf = (route.get("vrf") or "").lower()
    table = (route.get("routing_table") or "main").lower()
    return vrf in {"management", "mgmt-vrf", "mgmt"} or table in {"management", "mgmt-vrf"}


def _connected_prefixes(cfg: ParsedConfig) -> list[tuple[str, str]]:
    rows = []
    for addr in cfg.addresses:
        if addr.get("disabled"):
            continue
        vrf = (addr.get("vrf") or "").lower()
        if vrf in {"management", "mgmt-vrf", "mgmt"}:
            continue
        prefix = _prefix_from_address(addr)
        if prefix:
            rows.append((prefix, addr.get("interface") or ""))
    return rows


def _vlan_id(value: Any) -> str:
    if value is None or value == "":
        return ""
    text = str(value).strip()
    text = text.replace("VLAN", "").replace("Vlan", "").replace("vlan", "")
    return text.strip()


def _first_host(prefix: str) -> str:
    net = _net(prefix)
    if net is None:
        return ""
    for host in net.hosts():
        return str(host)
    return str(net.network_address)


def _vlan_prefix(roster: Roster, vlan: str) -> str:
    for cfg, _fn in roster:
        for iface in cfg.interfaces:
            if iface.get("kind") not in {"vlan", "svi"}:
                continue
            if str(iface.get("vlan_id") or "") != vlan:
                continue
            for addr in cfg.addresses:
                if addr.get("interface") == iface.get("name") and not addr.get("disabled"):
                    prefix = _prefix_from_address(addr)
                    if prefix:
                        return prefix
    return ""


def _hsrp_for_vlan(roster: Roster) -> dict[str, tuple[str, dict[str, Any], ParsedConfig, int]]:
    """vlan -> (device_id, hsrp row, cfg, index) of highest priority."""
    best: dict[str, tuple[int, str, dict[str, Any], ParsedConfig, int]] = {}
    for idx, (cfg, _fn) in enumerate(roster):
        for item in cfg.hsrp:
            vlan = str(item.get("vlan") or "")
            vip = item.get("vip") or ""
            if not vlan or not vip:
                continue
            pri = int(item.get("priority") or 0)
            prev = best.get(vlan)
            if prev is None or pri > prev[0]:
                best[vlan] = (pri, f"dev-{idx}", item, cfg, idx)
    return {vlan: (did, row, cfg, idx) for vlan, (_pri, did, row, cfg, idx) in best.items()}


def _svi_for_vlan(roster: Roster, vlan: str) -> tuple[str, str, ParsedConfig] | None:
    for idx, (cfg, _fn) in enumerate(roster):
        for iface in cfg.interfaces:
            if iface.get("kind") not in {"vlan", "svi"}:
                continue
            if str(iface.get("vlan_id") or "") != vlan:
                continue
            if iface.get("disabled"):
                continue
            for addr in cfg.addresses:
                if addr.get("interface") == iface.get("name") and not addr.get("disabled"):
                    host = (addr.get("address") or "").split("/", 1)[0]
                    if host:
                        return f"dev-{idx}", host, cfg
    return None


def _lpm(cfg: ParsedConfig, dest: ipaddress.IPv4Address) -> dict[str, Any] | None:
    best: dict[str, Any] | None = None
    best_len = -1
    best_dist = 10_000
    for route in cfg.routes:
        if route.get("disabled") or _is_mgmt(route):
            continue
        if (route.get("routing_table") or "main") != "main":
            continue
        net = _net(route.get("dst") or "")
        if net is None or dest not in net:
            continue
        dist = int(route.get("distance") or 1)
        plen = net.prefixlen
        if plen > best_len or (plen == best_len and dist < best_dist):
            best = route
            best_len = plen
            best_dist = dist
    return best


def _iface_kind(cfg: ParsedConfig, name: str) -> str:
    iface = cfg.iface_by_name(name)
    return (iface or {}).get("kind") or ""


def _find_owner(
    roster: Roster, ip: str, prefer_hsrp: bool = True
) -> tuple[str, ParsedConfig, str] | None:
    hits: list[tuple[int, str, ParsedConfig, str]] = []
    for idx, (cfg, _fn) in enumerate(roster):
        owned = owned_ips(cfg)
        info = owned.get(ip)
        if not info:
            continue
        pri = int(info.get("priority") or 0)
        hits.append((pri, f"dev-{idx}", cfg, info.get("iface") or ""))
    if not hits:
        return None
    if prefer_hsrp:
        hits.sort(key=lambda row: row[0], reverse=True)
    return hits[0][1], hits[0][2], hits[0][3]


def _gre_peer(
    mesh: dict[str, Any], device_id: str, tunnel: str
) -> tuple[str, str] | None:
    for link in mesh.get("links") or []:
        if link.get("kind") != "gre":
            continue
        if link.get("source") == device_id and link.get("a_tunnel") == tunnel:
            return link.get("target") or "", link.get("b_tunnel") or ""
        if link.get("target") == device_id and link.get("b_tunnel") == tunnel:
            return link.get("source") or "", link.get("a_tunnel") or ""
    return None


def _hop(
    device_id: str,
    cfg: ParsedConfig,
    kind: str,
    **extra: Any,
) -> dict[str, Any]:
    row = {
        "device_id": device_id,
        "device_name": cfg.identity,
        "kind": kind,
        "iface": extra.get("iface") or "",
        "vlan": extra.get("vlan") or "",
        "route_dst": extra.get("route_dst"),
        "gateway": extra.get("gateway") or "",
        "next_device": extra.get("next_device"),
        "note": extra.get("note") or "",
    }
    return row


def trace_path(
    roster: Roster,
    src: dict[str, Any],
    dst: str,
    mesh: dict[str, Any] | None = None,
) -> dict[str, Any]:
    dest = _ip(dst)
    if dest is None:
        return {"hops": [], "status": "drop", "reason": "invalid destination"}
    if not roster:
        return {"hops": [], "status": "drop", "reason": "empty site"}
    mesh = mesh or build_mesh(roster)
    by_id = {f"dev-{idx}": (cfg, filename, idx) for idx, (cfg, filename) in enumerate(roster)}
    device_id = src.get("device_id") or "dev-0"
    if device_id not in by_id:
        return {"hops": [], "status": "drop", "reason": "unknown device"}
    cfg, _fn, _idx = by_id[device_id]
    vlan = _vlan_id(src.get("vlan"))
    iface_name = src.get("interface") or ""
    if not vlan and iface_name:
        iface = cfg.iface_by_name(iface_name)
        if iface and iface.get("vlan_id"):
            vlan = str(iface.get("vlan_id"))
        elif iface and iface.get("access_vlan"):
            vlan = str(iface.get("access_vlan"))
        elif iface_name.upper().startswith("VLAN"):
            vlan = _vlan_id(iface_name)
    prefix = _vlan_prefix(roster, vlan) if vlan else ""
    client_ip = src.get("client_ip") or (_first_host(prefix) if prefix else "")
    hops: list[dict[str, Any]] = []
    hsrp_map = _hsrp_for_vlan(roster)

    current_id = device_id
    current_cfg = cfg
    if vlan:
        l2 = _l2_gateway(roster, hsrp_map, vlan, current_id, current_cfg, client_ip, mesh)
        hops.append(l2)
        nxt = l2.get("next_device")
        if l2["kind"] == "drop":
            return {"hops": hops, "status": "drop", "reason": l2.get("note") or "no L2 gateway", "client_ip": client_ip}
        if nxt and nxt in by_id and nxt != current_id:
            current_id, current_cfg = nxt, by_id[nxt][0]

    visited: set[str] = set()
    while len(hops) < MAX_HOPS:
        if current_id in visited:
            hops.append(
                _hop(current_id, current_cfg, "drop", note="loop")
            )
            return {"hops": hops, "status": "drop", "reason": "loop", "client_ip": client_ip}
        visited.add(current_id)
        connected = _connected_prefixes(current_cfg)
        hit = next((iface for prefix, iface in connected if (n := _net(prefix)) and dest in n), None)
        if hit is not None:
            hops.append(
                _hop(
                    current_id,
                    current_cfg,
                    "deliver",
                    iface=hit,
                    vlan=vlan,
                    gateway="",
                    note=f"{dst} connected",
                )
            )
            return {"hops": hops, "status": "deliver", "reason": "", "client_ip": client_ip}
        route = _lpm(current_cfg, dest)
        if route is None:
            hops.append(_hop(current_id, current_cfg, "drop", vlan=vlan, note="no route"))
            return {"hops": hops, "status": "drop", "reason": "no route", "client_ip": client_ip}
        gw = route.get("gateway") or ""
        gw_iface = resolve_gateway_interface(current_cfg, gw) or ""
        kind = _iface_kind(current_cfg, gw) or _iface_kind(current_cfg, gw_iface)
        if kind == "pppoe" or (gw_iface and _iface_kind(current_cfg, gw_iface) == "pppoe"):
            hops.append(
                _hop(
                    current_id,
                    current_cfg,
                    "egress",
                    iface=gw_iface or gw,
                    route_dst=route.get("dst"),
                    gateway=gw,
                    note="Internet",
                )
            )
            return {"hops": hops, "status": "egress", "reason": "", "client_ip": client_ip}
        if kind == "gre" or _iface_kind(current_cfg, gw) == "gre":
            tunnel = gw if current_cfg.iface_by_name(gw) else gw_iface
            peer = _gre_peer(mesh, current_id, tunnel)
            if not peer:
                hops.append(
                    _hop(
                        current_id,
                        current_cfg,
                        "drop",
                        iface=tunnel,
                        route_dst=route.get("dst"),
                        gateway=gw,
                        note="GRE peer missing",
                    )
                )
                return {"hops": hops, "status": "drop", "reason": "GRE peer missing", "client_ip": client_ip}
            next_id, peer_tun = peer
            hops.append(
                _hop(
                    current_id,
                    current_cfg,
                    "l3",
                    iface=tunnel,
                    route_dst=route.get("dst"),
                    gateway=gw,
                    next_device=next_id,
                    note=f"GRE {tunnel} → {by_id[next_id][0].identity if next_id in by_id else next_id}",
                )
            )
            if next_id not in by_id:
                hops.append(_hop(current_id, current_cfg, "drop", note="unknown GRE peer"))
                return {"hops": hops, "status": "drop", "reason": "unknown GRE peer", "client_ip": client_ip}
            current_id, current_cfg = next_id, by_id[next_id][0]
            _ = peer_tun
            continue
        owner = _find_owner(roster, gw)
        if owner:
            next_id, next_cfg, owner_iface = owner
            hops.append(
                _hop(
                    current_id,
                    current_cfg,
                    "l3",
                    iface=gw_iface or owner_iface,
                    vlan=vlan,
                    route_dst=route.get("dst"),
                    gateway=gw,
                    next_device=next_id,
                    note=f"via {gw} → {next_cfg.identity}",
                )
            )
            if next_id == current_id:
                hops.append(_hop(current_id, current_cfg, "drop", note="next-hop is local"))
                return {"hops": hops, "status": "drop", "reason": "next-hop is local", "client_ip": client_ip}
            current_id, current_cfg = next_id, next_cfg
            continue
        hops.append(
            _hop(
                current_id,
                current_cfg,
                "drop",
                iface=gw_iface or gw,
                route_dst=route.get("dst"),
                gateway=gw,
                note="unknown next-hop",
            )
        )
        return {"hops": hops, "status": "drop", "reason": "unknown next-hop", "client_ip": client_ip}

    hops.append(_hop(current_id, current_cfg, "drop", note="hop limit"))
    return {"hops": hops, "status": "drop", "reason": "hop limit", "client_ip": client_ip}


def _l2_gateway(
    roster: Roster,
    hsrp_map: dict[str, tuple[str, dict[str, Any], ParsedConfig, int]],
    vlan: str,
    device_id: str,
    cfg: ParsedConfig,
    client_ip: str,
    mesh: dict[str, Any],
) -> dict[str, Any]:
    active = hsrp_map.get(vlan)
    if active:
        next_id, item, next_cfg, _idx = active
        vip = item.get("vip") or ""
        note = f"HSRP VLAN{vlan} VIP {vip} → {next_cfg.identity}"
        if next_id == device_id:
            note = f"HSRP VLAN{vlan} VIP {vip} local"
        return _hop(
            device_id,
            cfg,
            "l2",
            iface=f"VLAN{vlan}",
            vlan=vlan,
            gateway=vip,
            next_device=next_id,
            note=note if not client_ip else f"{note} (client {client_ip})",
        )
    svi = _svi_for_vlan(roster, vlan)
    if svi:
        next_id, host, next_cfg = svi
        return _hop(
            device_id,
            cfg,
            "l2",
            iface=f"VLAN{vlan}",
            vlan=vlan,
            gateway=host,
            next_device=next_id,
            note=f"SVI VLAN{vlan} {host} → {next_cfg.identity}",
        )
    if cfg.iface_by_name(f"Vlan{vlan}") or cfg.iface_by_name(f"VLAN{vlan}"):
        return _hop(device_id, cfg, "l2", iface=f"VLAN{vlan}", vlan=vlan, next_device=device_id, note="local VLAN")
    _ = mesh
    return _hop(device_id, cfg, "drop", vlan=vlan, note=f"no gateway for VLAN{vlan}")
