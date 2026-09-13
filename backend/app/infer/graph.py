"""Build a compact, readable zone schematic (not a hairball of every port)."""

from __future__ import annotations

from collections import defaultdict
from typing import Any
import re

from app.infer.direction import (
    infer_nat_direction,
    infer_route_direction,
    resolve_gateway_interface,
    zone_for_interface,
)
from app.parsers.rsc import ParsedConfig

PHYSICAL_ORDER = [f"ether{i}" for i in range(1, 17)] + ["sfp-sfpplus1", "sfp-sfpplus2"]


def _nid(prefix: str, local: str) -> str:
    return f"{prefix}:{local}" if prefix else local


def _node(node_id: str, ntype: str, label: str, x: float, y: float, **data: Any) -> dict[str, Any]:
    return {
        "id": node_id,
        "type": ntype,
        "position": {"x": x, "y": y},
        "data": {"label": label, **data},
    }


def _edge(edge_id: str, source: str, target: str, kind: str, direction: str, **data: Any) -> dict[str, Any]:
    return {
        "id": edge_id,
        "source": source,
        "target": target,
        "kind": kind,
        "direction": direction,
        "data": data,
    }


def _prefix_from_address(addr: dict[str, Any]) -> str:
    if addr.get("network") and "/" in (addr.get("address") or ""):
        mask = addr["address"].split("/", 1)[1]
        return f"{addr['network']}/{mask}"
    return addr.get("address") or ""


def _addresses_for(cfg: ParsedConfig, name: str) -> list[dict[str, Any]]:
    return [a for a in cfg.addresses if a.get("interface") == name]


def _prefixes_for(cfg: ParsedConfig, name: str) -> list[str]:
    out = []
    for addr in _addresses_for(cfg, name):
        prefix = _prefix_from_address(addr)
        if prefix:
            out.append(prefix)
    return out


def _ifaces_in_list(cfg: ParsedConfig, list_name: str) -> set[str]:
    want = list_name.upper()
    return {
        m.get("interface") or ""
        for m in cfg.list_members
        if not m.get("disabled") and (m.get("list") or "").upper() == want
    }


def _ether_sort(name: str) -> tuple:
    if name.startswith("ether"):
        try:
            return (0, int(name[5:]))
        except ValueError:
            return (0, 10_000)
    if name.startswith("sfp"):
        return (1, name)
    return (2, name)


def _is_switch(cfg: ParsedConfig) -> bool:
    if (cfg.role or "") == "switch" or (cfg.vendor or "") == "cisco":
        return True
    return bool(cfg.access_ports)


def _physical_names(cfg: ParsedConfig) -> list[str]:
    if _is_switch(cfg):
        names: list[str] = []
        for iface in cfg.interfaces:
            if iface.get("kind") != "bonding" or iface.get("disabled"):
                continue
            name = iface.get("name") or ""
            if name and name not in names:
                names.append(name)
        return names
    model = (cfg.model or "").upper()
    if "CCR2004" in model and "16G" in model:
        return list(PHYSICAL_ORDER)
    present = {iface.get("name") or "" for iface in cfg.interfaces}
    if all(f"ether{i}" in present for i in range(1, 17)):
        names = list(PHYSICAL_ORDER)
        extra = [
            iface.get("name") or ""
            for iface in cfg.interfaces
            if (iface.get("kind") == "ethernet" or (iface.get("name") or "").startswith("sfp"))
            and (iface.get("name") or "") not in names
        ]
        return names + extra
    found: list[str] = []
    for iface in cfg.interfaces:
        name = iface.get("name") or ""
        kind = iface.get("kind") or ""
        if not name:
            continue
        if kind == "ethernet" or name.startswith("ether") or name.startswith("sfp"):
            if name not in found:
                found.append(name)
    found.sort(key=_ether_sort)
    return found


def build_graph(cfg: ParsedConfig, id_prefix: str = "") -> dict[str, Any]:
    nodes: list[dict[str, Any]] = []
    edges: list[dict[str, Any]] = []
    used_ids: set[str] = set()

    def add_node(node: dict[str, Any]) -> None:
        if node["id"] in used_ids:
            return
        used_ids.add(node["id"])
        nodes.append(node)

    def nid(local: str) -> str:
        return _nid(id_prefix, local)

    router_id = nid("router")
    model = cfg.model or ""
    add_node(
        _node(
            router_id,
            "router",
            cfg.identity,
            390,
            150,
            model=model,
            ports=_port_summaries(cfg),
        )
    )
    add_node(_node(nid("label:lan"), "zoneLabel", "LAN", 40, 8, zone="LAN"))
    add_node(_node(nid("label:wan"), "zoneLabel", "WAN / Internet", 820, 8, zone="WAN"))
    add_node(_node(nid("label:vpn"), "zoneLabel", "VPN / туннели", 40, 548, zone="VPN"))

    wan_set = _ifaces_in_list(cfg, "WAN")
    lan_set = _ifaces_in_list(cfg, "LAN")

    lan_ifaces = _lan_ifaces(cfg, lan_set)
    for idx, iface in enumerate(lan_ifaces):
        _add_iface_card(
            add_node,
            cfg,
            iface,
            x=40,
            y=56 + idx * 118,
            zone="LAN",
            id_prefix=id_prefix,
        )
        edges.append(
            _edge(
                nid(f"e:lan-{iface['name']}"),
                nid(f"iface:{iface['name']}"),
                router_id,
                "l2",
                "local",
                zone="LAN",
            )
        )

    if not _is_switch(cfg):
        for iface in cfg.interfaces:
            if iface.get("kind") != "bonding" or iface.get("disabled"):
                continue
            _add_iface_card(add_node, cfg, iface, x=390, y=430, zone="LAN", id_prefix=id_prefix)
            edges.append(
                _edge(
                    nid(f"e:bond-{iface['name']}"),
                    nid(f"iface:{iface['name']}"),
                    router_id,
                    "bonding",
                    "local",
                    zone="LAN",
                )
            )

    wan_ifaces = _wan_ifaces(cfg, wan_set)
    for idx, iface in enumerate(wan_ifaces):
        _add_iface_card(add_node, cfg, iface, x=820, y=56 + idx * 150, zone="WAN", id_prefix=id_prefix)
        edges.append(
            _edge(
                nid(f"e:default-{iface['name']}"),
                router_id,
                nid(f"iface:{iface['name']}"),
                "default",
                "egress",
                label="default + SRC-NAT" if iface.get("kind") == "pppoe" else iface.get("comment") or "WAN",
            )
        )

    vpn_ifaces = [
        iface
        for iface in cfg.interfaces
        if not iface.get("disabled")
        and (iface.get("kind") == "gre" or "VPN" in (iface.get("name") or "").upper())
        and iface.get("kind") != "ethernet"
    ]
    vpn_ifaces.sort(key=lambda i: i.get("name") or "")
    for idx, iface in enumerate(vpn_ifaces):
        col, row = idx % 3, idx // 3
        _add_iface_card(
            add_node,
            cfg,
            iface,
            x=40 + col * 250,
            y=600 + row * 130,
            zone="VPN",
            id_prefix=id_prefix,
        )
        edges.append(
            _edge(
                nid(f"e:vpn-{iface['name']}"),
                router_id,
                nid(f"iface:{iface['name']}"),
                "tunnel" if iface.get("kind") == "gre" else "attached",
                "tunnel",
                zone="VPN",
            )
        )
        if iface.get("kind") == "gre" and iface.get("remote_address"):
            card = next(n for n in nodes if n["id"] == nid(f"iface:{iface['name']}"))
            card["data"]["peer_id"] = nid(f"peer:{iface['remote_address']}")

    routes_out: list[dict[str, Any]] = []
    bundles: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for idx, route in enumerate(cfg.routes):
        direction = infer_route_direction(cfg, route)
        gw_iface = resolve_gateway_interface(cfg, route.get("gateway") or "")
        item = {
            "id": nid(f"route-{idx}"),
            "dst": route.get("dst"),
            "gateway": route.get("gateway"),
            "interface": gw_iface,
            "distance": route.get("distance"),
            "routing_table": route.get("routing_table") or "main",
            "comment": route.get("comment", ""),
            "disabled": bool(route.get("disabled")),
            "synthetic": bool(route.get("synthetic")),
            "direction": direction,
            "zone": zone_for_interface(cfg, gw_iface) if gw_iface else "UNKNOWN",
        }
        routes_out.append(item)
        if not item["disabled"]:
            key = f"{item['gateway']}|{item['routing_table']}|{item['direction']}"
            bundles[key].append(item)

    for bundle_idx, (key, group) in enumerate(bundles.items()):
        gateway, table, direction = key.split("|", 2)
        gw_iface = resolve_gateway_interface(cfg, gateway)
        iface_target = nid(f"iface:{gw_iface}") if gw_iface else ""
        target = iface_target if gw_iface and iface_target in used_ids else router_id
        bid = nid(f"bundle:{bundle_idx}")
        add_node(
            _node(
                bid,
                "bundle",
                f"via {gateway or '?'} ({len(group)})",
                -4000,
                -4000,
                zone=group[0]["zone"],
                direction=direction,
                gateway=gateway,
                routing_table=table,
                count=len(group),
                route_ids=[r["id"] for r in group],
                hidden=True,
            )
        )
        edges.append(
            _edge(
                nid(f"e:bundle:{bundle_idx}"),
                bid,
                target,
                "nexthop",
                direction,
                routing_table=table,
                count=len(group),
            )
        )
        if table != "main" and target != router_id:
            policy_id = nid(f"e:policy-{table}-{gw_iface}")
            if not any(e["id"] == policy_id for e in edges):
                edges.append(
                    _edge(
                        policy_id,
                        router_id,
                        target,
                        "policy",
                        "policy",
                        routing_table=table,
                        label=table,
                    )
                )

    nats_out: list[dict[str, Any]] = []
    inbound: list[str] = []
    wan_id = next((nid(f"iface:{i['name']}") for i in wan_ifaces), router_id)
    egress_nat_added = False
    for idx, rule in enumerate(cfg.nat):
        direction = infer_nat_direction(rule)
        if direction is None and rule.get("disabled"):
            direction = "disabled"
        item = {**rule, "id": nid(f"nat-{idx}"), "direction": direction}
        nats_out.append(item)
        if rule.get("disabled") or direction is None:
            continue
        if direction == "egress" and wan_id in used_ids and not egress_nat_added:
            egress_nat_added = True
            edges.append(
                _edge(
                    nid("e:nat-src"),
                    router_id,
                    wan_id,
                    "nat",
                    "egress",
                    comment=rule.get("comment", ""),
                    label=rule.get("comment") or "SRC-NAT",
                )
            )
        if direction == "ingress" and rule.get("to_addresses"):
            port = rule.get("dst_port") or ""
            inbound.append(_nat_line(rule, port))

    if inbound:
        add_node(
            _node(
                nid("service:inbound"),
                "service",
                "Входящий DNAT",
                820,
                280,
                zone="WAN",
                lines=inbound[:8],
                extra=max(0, len(inbound) - 8),
            )
        )
        edges.append(
            _edge(
                nid("e:nat-in"),
                wan_id if wan_id in used_ids else router_id,
                nid("service:inbound"),
                "nat",
                "ingress",
            )
        )

    for iface in cfg.interfaces:
        if iface.get("kind") == "gre" and iface.get("remote_address"):
            add_node(
                _node(
                    nid(f"peer:{iface['remote_address']}"),
                    "peer",
                    iface.get("comment") or iface["remote_address"],
                    -4000,
                    -4000,
                    zone="VPN",
                    hidden=True,
                    address=iface["remote_address"],
                    tunnel=iface["name"],
                )
            )
    for addr in cfg.addresses:
        prefix = _prefix_from_address(addr)
        if prefix:
            add_node(
                _node(
                    nid(f"prefix:{prefix}"),
                    "prefix",
                    prefix,
                    -4000,
                    -4000,
                    hidden=True,
                    zone=zone_for_interface(cfg, addr.get("interface") or ""),
                    interface=addr.get("interface", ""),
                )
            )

    return {
        "router": {"name": cfg.identity, "model": model},
        "nodes": nodes,
        "edges": edges,
        "routes": routes_out,
        "nats": nats_out,
        "tables": cfg.routing_tables,
        "stats": {
            "interfaces": len(cfg.interfaces),
            "addresses": len(cfg.addresses),
            "routes": len(routes_out),
            "routes_enabled": sum(1 for r in routes_out if not r["disabled"]),
            "nats": len(nats_out),
        },
    }


def _lan_ifaces(cfg: ParsedConfig, lan_set: set[str]) -> list[dict[str, Any]]:
    picked: list[dict[str, Any]] = []
    seen: set[str] = set()
    for iface in cfg.interfaces:
        if iface.get("disabled"):
            continue
        name = iface.get("name") or ""
        kind = iface.get("kind")
        if not name or name in seen:
            continue
        if kind in {"bonding", "pppoe", "gre", "mgmt", "ethernet"}:
            continue
        zone = zone_for_interface(cfg, name)
        take = False
        if kind in {"vlan", "svi"}:
            take = bool(_prefixes_for(cfg, name)) if _is_switch(cfg) else True
        elif kind == "bridge" and zone == "LAN":
            take = True
        elif name in lan_set and zone in {"LAN", "DMZ"}:
            take = True
        if not take:
            continue
        seen.add(name)
        picked.append(iface)
    picked.extend(_vlan_group_cards(cfg, seen))

    def sort_key(iface: dict[str, Any]) -> tuple:
        kind = iface.get("kind")
        if kind == "vlan":
            try:
                return (0, int(iface.get("vlan_id") or 999), iface.get("name") or "")
            except ValueError:
                return (0, 999, iface.get("name") or "")
        if kind == "bridge":
            return (1, 0, iface.get("name") or "")
        return (2, 0, iface.get("name") or "")

    picked.sort(key=sort_key)
    return picked


def _wan_ifaces(cfg: ParsedConfig, wan_set: set[str]) -> list[dict[str, Any]]:
    picked: list[dict[str, Any]] = []
    seen: set[str] = set()
    for iface in cfg.interfaces:
        if iface.get("disabled"):
            continue
        name = iface.get("name") or ""
        kind = iface.get("kind")
        if not name or name in seen:
            continue
        if kind == "gre":
            continue
        if kind == "pppoe" or name in wan_set:
            seen.add(name)
            picked.append(iface)
    picked.sort(key=lambda i: (0 if i.get("kind") == "pppoe" else 1, i.get("name") or ""))
    return picked


def _add_iface_card(
    add_node,
    cfg: ParsedConfig,
    iface: dict[str, Any],
    x: float,
    y: float,
    zone: str,
    id_prefix: str = "",
) -> None:
    name = iface["name"]
    prefixes = _prefixes_for(cfg, name)
    lines = []
    if iface.get("comment"):
        lines.append(iface["comment"])
    lines.extend(prefixes)
    if iface.get("remote_address"):
        lines.append(f"peer {iface['remote_address']}")
    if iface.get("vlan_id"):
        lines.append(f"VLAN {iface['vlan_id']}")
    if iface.get("slaves"):
        lines.append(iface["slaves"].replace("sfp-sfpplus", "sfp+"))
    if iface.get("kind") == "pppoe":
        lines.append("default route → Internet")
    for item in cfg.hsrp:
        if item.get("interface") == name and item.get("vip"):
            lines.append(f"HSRP {item['vip']} pri {item.get('priority') or ''}")
    if iface.get("access_count"):
        lines.append(f"{iface['access_count']} access ports")
    for note in iface.get("access_notes") or []:
        lines.append(note)
    add_node(
        _node(
            _nid(id_prefix, f"iface:{name}"),
            "interface",
            name,
            x,
            y,
            kind=iface.get("kind"),
            zone=zone,
            comment=iface.get("comment", ""),
            prefixes=prefixes,
            lines=lines,
            remote_address=iface.get("remote_address", ""),
            disabled=bool(iface.get("disabled")),
        )
    )


def _nat_line(rule: dict[str, Any], port: str) -> str:
    dest = rule.get("to_addresses") or ""
    proto = rule.get("protocol") or ""
    left = ":".join(part for part in (proto, port) if part)
    return f"{left} → {dest}"


def _vlan_group_cards(cfg: ParsedConfig, seen: set[str]) -> list[dict[str, Any]]:
    svi_vlans = {
        str(iface.get("vlan_id") or "")
        for iface in cfg.interfaces
        if iface.get("kind") in {"vlan", "svi"} and _prefixes_for(cfg, iface.get("name") or "")
    }
    by_vlan: dict[str, list[dict[str, Any]]] = {}
    for ap in cfg.access_ports:
        if ap.get("disabled"):
            continue
        vid = str(ap.get("vlan") or "")
        if not vid:
            continue
        by_vlan.setdefault(vid, []).append(ap)
    extra: list[dict[str, Any]] = []
    for vid, ports in sorted(by_vlan.items(), key=lambda kv: int(kv[0]) if kv[0].isdigit() else 0):
        if vid in svi_vlans:
            svi = next(
                (
                    iface
                    for iface in cfg.interfaces
                    if iface.get("kind") in {"vlan", "svi"} and str(iface.get("vlan_id") or "") == vid
                ),
                None,
            )
            if svi is not None:
                svi["access_count"] = len(ports)
                notes = [
                    f"{p['name']} {p.get('description') or ''}".strip()
                    for p in ports
                    if p.get("description")
                ]
                svi["access_notes"] = notes[:4]
            continue
        name = f"VLAN{vid}"
        if name in seen:
            continue
        seen.add(name)
        notes = [
            f"{p['name']} {p.get('description') or ''}".strip()
            for p in ports
            if p.get("description")
        ]
        extra.append(
            {
                "name": name,
                "kind": "vlan-group",
                "vlan_id": vid,
                "comment": f"{len(ports)} access ports",
                "disabled": False,
                "access_count": len(ports),
                "access_notes": notes[:4],
            }
        )
    return extra


def _port_summaries(cfg: ParsedConfig) -> list[dict[str, Any]]:
    ports = []
    for name in _physical_names(cfg):
        iface = cfg.iface_by_name(name) or {}
        display = name
        if _is_switch(cfg):
            display = re.sub(r"(?i)port-channel", "Po", name)
        ports.append(
            {
                "name": display,
                "comment": iface.get("comment", ""),
                "zone": zone_for_interface(cfg, name),
                "kind": "sfp" if "vpc" in str(iface.get("vpc") or "").lower() or name.lower().startswith("sfp") else "ether",
            }
        )
    return ports
