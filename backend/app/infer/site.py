"""Build a flat inter-device mesh (no hub/peer) from independent configs."""

from __future__ import annotations

import ipaddress
import re
from typing import Any

from app.infer.direction import infer_route_direction, resolve_gateway_interface
from app.infer.graph import _prefix_from_address, build_graph
from app.parsers.rsc import ParsedConfig

Roster = list[tuple[ParsedConfig, str]]


def device_role(cfg: ParsedConfig) -> str:
    if cfg.role in {"router", "switch"}:
        return cfg.role
    if (cfg.vendor or "") == "cisco":
        return "switch"
    return "router"


def _gre_tunnels(cfg: ParsedConfig) -> list[dict[str, str]]:
    tunnels = []
    for iface in cfg.interfaces:
        if iface.get("kind") != "gre" or iface.get("disabled"):
            continue
        tunnels.append(
            {
                "name": iface.get("name") or "",
                "comment": iface.get("comment") or "",
                "local": iface.get("local_address") or "",
                "remote": iface.get("remote_address") or "",
            }
        )
    return tunnels


def _prefixes(cfg: ParsedConfig) -> list[str]:
    out = []
    for addr in cfg.addresses:
        if addr.get("disabled") or _is_mgmt_vrf(addr.get("vrf")):
            continue
        prefix = _prefix_from_address(addr)
        if prefix:
            out.append(prefix)
    return out


def _is_mgmt_vrf(vrf: str | None) -> bool:
    if not vrf:
        return False
    return vrf.lower() in {"management", "mgmt-vrf", "mgmt"}


def _pair_gre(left: ParsedConfig, right: ParsedConfig) -> list[dict[str, str]]:
    """Only a real GRE if local/remote are swapped on both ends."""
    links = []
    for a in _gre_tunnels(left):
        if not a["local"] or not a["remote"]:
            continue
        for b in _gre_tunnels(right):
            if a["remote"] == b["local"] and a["local"] == b["remote"]:
                links.append(
                    {
                        "a_tunnel": a["name"],
                        "a_comment": a["comment"],
                        "b_tunnel": b["name"],
                        "b_comment": b["comment"],
                        "a_ip": a["local"],
                        "b_ip": b["local"],
                        "kind": "gre",
                    }
                )
    return links


def _net(value: str) -> ipaddress.IPv4Network | None:
    if not value:
        return None
    try:
        return ipaddress.ip_network(value, strict=False)
    except ValueError:
        return None


def _dst_of_connected(dst: str, prefix: str) -> bool:
    """Route dst matches connected prefix or is a more-specific subnet of it."""
    if dst == prefix:
        return True
    route_net = _net(dst)
    owned = _net(prefix)
    if route_net is None or owned is None:
        return False
    return route_net == owned or route_net.subnet_of(owned)


def _connected_looking(cfg: ParsedConfig) -> list[str]:
    found: list[str] = []
    seen: set[str] = set()

    def add(prefix: str) -> None:
        if prefix and prefix not in seen and prefix not in {"0.0.0.0/0", "0.0.0.0"}:
            seen.add(prefix)
            found.append(prefix)

    for addr in cfg.addresses:
        if addr.get("disabled") or _is_mgmt_vrf(addr.get("vrf")):
            continue
        add(_prefix_from_address(addr))
    for route in cfg.routes:
        if route.get("disabled"):
            continue
        if infer_route_direction(cfg, route) == "local":
            add(route.get("dst") or "")
    return found


def _enabled_via(cfg: ParsedConfig, tunnel: str) -> list[dict[str, Any]]:
    out = []
    for route in cfg.routes:
        if route.get("disabled"):
            continue
        gw = route.get("gateway") or ""
        iface = resolve_gateway_interface(cfg, gw)
        if gw == tunnel or iface == tunnel:
            out.append(route)
    return out


def _uniq_rows(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    seen: set[tuple] = set()
    out = []
    for row in rows:
        key = (row.get("dst"), row.get("from"), row.get("to"), row.get("via_tunnel"), row.get("origin"))
        if key in seen:
            continue
        seen.add(key)
        out.append(row)
    return out


def _exchange_pair(
    cfg_a: ParsedConfig,
    name_a: str,
    tun_a: str,
    cfg_b: ParsedConfig,
    name_b: str,
    tun_b: str,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]]]:
    connected_a = _connected_looking(cfg_a)
    connected_b = _connected_looking(cfg_b)
    routes_on_b = _enabled_via(cfg_b, tun_b)
    routes_on_a = _enabled_via(cfg_a, tun_a)

    advertised: list[dict[str, Any]] = []
    for zatupa in routes_on_b:
        dst = zatupa.get("dst") or ""
        if any(_dst_of_connected(dst, pref) for pref in connected_a):
            advertised.append(
                {
                    "dst": dst,
                    "from": name_a,
                    "to": name_b,
                    "via_tunnel": tun_b,
                    "peer_tunnel": tun_a,
                    "origin": "connected",
                }
            )

    received: list[dict[str, Any]] = []
    forwarded: list[dict[str, Any]] = []
    for route in routes_on_a:
        dst = route.get("dst") or ""
        hit = any(_dst_of_connected(dst, pref) for pref in connected_b)
        if hit:
            received.append(
                {
                    "dst": dst,
                    "from": name_b,
                    "to": name_a,
                    "via_tunnel": tun_a,
                    "peer_tunnel": tun_b,
                    "origin": "connected",
                }
            )
        else:
            forwarded.append(
                {
                    "dst": dst,
                    "from": name_a,
                    "to": name_b,
                    "via_tunnel": tun_a,
                    "peer_tunnel": tun_b,
                    "origin": "static",
                }
            )
    return _uniq_rows(advertised), _uniq_rows(received), _uniq_rows(forwarded)


def _slug(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", (value or "").lower())


def _short_if(name: str) -> str:
    n = name or ""
    n = re.sub(r"(?i)port-channel", "Po", n)
    n = re.sub(r"(?i)tengigabitethernet", "Te", n)
    n = re.sub(r"(?i)gigabitethernet", "Gi", n)
    return n


def _mentions_device(text: str, cfg: ParsedConfig) -> bool:
    ident = (cfg.identity or "").strip()
    if not ident or not text:
        return False
    return _slug(ident) in _slug(text) if len(_slug(ident)) >= 3 else False


def _iface_aliases(name: str) -> set[str]:
    n = (name or "").lower()
    aliases = {_slug(n)}
    swapped = (
        n.replace("tengigabitethernet", "ten")
        .replace("gigabitethernet", "gi")
        .replace("ethernet", "eth")
        .replace("sfp-sfpplus", "sfpplus")
    )
    aliases.add(_slug(swapped))
    aliases.add(_slug(n.replace("sfp-sfpplus", "sfpplus")))
    return {a for a in aliases if len(a) >= 3}


def _desc_mentions_iface(desc: str, iface_name: str) -> bool:
    blob = _slug(desc)
    return any(alias in blob for alias in _iface_aliases(iface_name))


def _bonding_ifaces(cfg: ParsedConfig) -> list[dict[str, Any]]:
    return [i for i in cfg.interfaces if i.get("kind") == "bonding" and not i.get("disabled")]


def _bundle_of(cfg: ParsedConfig, iface: dict[str, Any]) -> str:
    name = iface.get("name") or ""
    if iface.get("kind") == "bonding":
        return name
    cg = iface.get("channel_group")
    if cg:
        for bond in _bonding_ifaces(cfg):
            if re.search(rf"(?i)port-channel{cg}$", bond.get("name") or ""):
                return bond["name"]
    for bond in _bonding_ifaces(cfg):
        slaves = [s.strip() for s in (bond.get("slaves") or "").split(",") if s.strip()]
        if name in slaves:
            return bond["name"]
    return name


def _best_bundle_on(cfg: ParsedConfig, peer: ParsedConfig, hint_desc: str) -> str:
    bonds = _bonding_ifaces(cfg)
    if not bonds:
        return ""
    for bond in bonds:
        if _mentions_device(bond.get("comment") or "", peer):
            return bond["name"]
    for iface in cfg.interfaces:
        desc = iface.get("comment") or ""
        if hint_desc and _desc_mentions_iface(hint_desc, iface.get("name") or ""):
            return _bundle_of(cfg, iface)
        if _mentions_device(desc, peer) and iface.get("channel_group"):
            return _bundle_of(cfg, iface)
    if len(bonds) == 1:
        return bonds[0]["name"]
    return ""


def _pair_lacp(left: ParsedConfig, right: ParsedConfig) -> list[dict[str, str]]:
    found: list[dict[str, str]] = []
    seen: set[tuple[str, str]] = set()

    def add(a_if: str, b_if: str, detail: str) -> None:
        if not a_if or not b_if:
            return
        key = (a_if.lower(), b_if.lower())
        if key in seen:
            return
        seen.add(key)
        found.append(
            {
                "kind": "lacp",
                "a_iface": a_if,
                "b_iface": b_if,
                "detail": detail,
                "label": f"{_short_if(a_if)} ↔ {_short_if(b_if)}",
            }
        )

    for iface in left.interfaces:
        if iface.get("disabled"):
            continue
        desc = iface.get("comment") or ""
        if not _mentions_device(desc, right) and not (
            iface.get("kind") == "bonding" and _mentions_device(iface.get("name") or "", right)
        ):
            continue
        a_if = _bundle_of(left, iface)
        b_if = _best_bundle_on(right, left, desc)
        add(a_if, b_if, desc)

    for iface in right.interfaces:
        if iface.get("disabled"):
            continue
        desc = iface.get("comment") or ""
        if not _mentions_device(desc, left):
            continue
        b_if = _bundle_of(right, iface)
        a_if = _best_bundle_on(left, right, desc)
        add(a_if, b_if, desc)
    return found


def _pair_vpc(left: ParsedConfig, right: ParsedConfig) -> list[dict[str, str]]:
    pa = next((i for i in left.interfaces if (i.get("vpc") or "").lower() == "peer-link"), None)
    pb = next((i for i in right.interfaces if (i.get("vpc") or "").lower() == "peer-link"), None)
    if not pa or not pb:
        return []
    return [
        {
            "kind": "vpc",
            "a_iface": pa["name"],
            "b_iface": pb["name"],
            "label": "vpc peer-link",
            "detail": pa.get("comment") or "VPC-peer-link",
        }
    ]


def _svi_nets(cfg: ParsedConfig) -> list[tuple[str, str, str]]:
    rows = []
    for addr in cfg.addresses:
        if addr.get("disabled") or _is_mgmt_vrf(addr.get("vrf")):
            continue
        iface = cfg.iface_by_name(addr.get("interface") or "")
        if not iface or iface.get("kind") not in {"vlan", "svi"}:
            continue
        prefix = _prefix_from_address(addr)
        if not prefix:
            continue
        vlan = str(iface.get("vlan_id") or "")
        rows.append((prefix, iface.get("name") or "", vlan))
    return rows


def _pair_svi(left: ParsedConfig, right: ParsedConfig) -> list[dict[str, str]]:
    links = []
    seen: set[str] = set()
    for prefix_a, if_a, vlan_a in _svi_nets(left):
        for prefix_b, if_b, vlan_b in _svi_nets(right):
            if prefix_a != prefix_b:
                continue
            if prefix_a in seen:
                continue
            seen.add(prefix_a)
            vlan = vlan_a or vlan_b
            tag = f"VLAN{vlan} " if vlan else ""
            links.append(
                {
                    "kind": "svi",
                    "a_iface": if_a,
                    "b_iface": if_b,
                    "label": f"{tag}{prefix_a}".strip(),
                    "detail": prefix_a,
                }
            )
    return links


def owned_ips(cfg: ParsedConfig) -> dict[str, dict[str, Any]]:
    found: dict[str, dict[str, Any]] = {}
    for addr in cfg.addresses:
        if addr.get("disabled") or _is_mgmt_vrf(addr.get("vrf")):
            continue
        host = (addr.get("address") or "").split("/", 1)[0]
        if not host:
            continue
        found[host] = {
            "iface": addr.get("interface") or "",
            "kind": "address",
            "priority": 0,
        }
    for item in cfg.hsrp:
        vip = item.get("vip") or ""
        if not vip:
            continue
        prev = found.get(vip)
        priority = int(item.get("priority") or 0)
        if prev is None or priority >= int(prev.get("priority") or 0):
            found[vip] = {
                "iface": item.get("interface") or "",
                "kind": "hsrp",
                "priority": priority,
                "vlan": str(item.get("vlan") or ""),
            }
    return found


def _pair_nexthop(left: ParsedConfig, right: ParsedConfig) -> list[dict[str, str]]:
    owned_b = owned_ips(right)
    seen: set[str] = set()
    links = []
    for route in left.routes:
        if route.get("disabled") or _is_mgmt_vrf(route.get("vrf")):
            continue
        if (route.get("routing_table") or "main") != "main":
            continue
        gw = route.get("gateway") or ""
        if gw not in owned_b or gw in seen:
            continue
        seen.add(gw)
        info = owned_b[gw]
        links.append(
            {
                "kind": "nexthop",
                "a_iface": resolve_gateway_interface(left, gw) or "",
                "b_iface": info.get("iface") or "",
                "label": f"via {gw}",
                "detail": gw,
            }
        )
    return links


def _attachments(cfg: ParsedConfig) -> list[dict[str, Any]]:
    items: list[dict[str, Any]] = []
    seen_vlans: set[str] = set()
    for ap in cfg.access_ports:
        if ap.get("disabled"):
            continue
        vid = str(ap.get("vlan") or "")
        if not vid or vid in seen_vlans:
            continue
        seen_vlans.add(vid)
        count = sum(
            1 for row in cfg.access_ports if str(row.get("vlan")) == vid and not row.get("disabled")
        )
        items.append(
            {
                "kind": "vlan",
                "vlan": vid,
                "id": vid,
                "name": f"VLAN{vid}",
                "label": f"VLAN{vid} × {count}",
            }
        )
    for iface in cfg.interfaces:
        if iface.get("disabled"):
            continue
        kind = iface.get("kind")
        if kind not in {"vlan", "svi", "gre", "pppoe"}:
            continue
        items.append(
            {
                "kind": "iface",
                "name": iface["name"],
                "label": iface["name"],
                "vlan": str(iface.get("vlan_id") or "") or None,
            }
        )
    return items


def _link_payload(
    i: int,
    j: int,
    left: ParsedConfig,
    right: ParsedConfig,
    pair: dict[str, str],
) -> dict[str, Any]:
    kind = pair.get("kind") or "gre"
    row: dict[str, Any] = {
        "source": f"dev-{i}",
        "target": f"dev-{j}",
        "source_name": left.identity,
        "target_name": right.identity,
        "kind": kind,
        "label": pair.get("label") or "",
        "detail": pair.get("detail") or "",
        "a_iface": pair.get("a_iface") or pair.get("a_tunnel") or "",
        "b_iface": pair.get("b_iface") or pair.get("b_tunnel") or "",
    }
    if kind == "gre":
        row.update(
            {
                "a_tunnel": pair.get("a_tunnel") or "",
                "b_tunnel": pair.get("b_tunnel") or "",
                "a_ip": pair.get("a_ip") or "",
                "b_ip": pair.get("b_ip") or "",
                "a_comment": pair.get("a_comment") or "",
                "b_comment": pair.get("b_comment") or "",
                "label": pair.get("label")
                or f"{pair.get('a_tunnel')} ↔ {pair.get('b_tunnel')}",
                "detail": " / ".join(
                    part for part in (pair.get("a_comment"), pair.get("b_comment")) if part
                ),
            }
        )
    return row


TOPO_KINDS = frozenset({"gre", "lacp", "vpc", "nexthop"})
MAP_KINDS = TOPO_KINDS


def _pair_ends(link: dict[str, Any]) -> tuple[str, str]:
    a = link.get("source") or ""
    b = link.get("target") or ""
    return (a, b) if a <= b else (b, a)


def _iface_pair(link: dict[str, Any]) -> tuple[str, str]:
    a = (link.get("a_iface") or link.get("a_tunnel") or "").lower()
    b = (link.get("b_iface") or link.get("b_tunnel") or "").lower()
    return (a, b) if a <= b else (b, a)


def _topo_bucket(link: dict[str, Any]) -> tuple:
    kind = link.get("kind") or ""
    if kind == "nexthop":
        gw = (link.get("detail") or link.get("label") or "").lower()
        return ("nexthop", link.get("source") or "", link.get("target") or "", gw)
    lo, hi = _pair_ends(link)
    if kind in {"lacp", "gre"}:
        return (kind, lo, hi, _iface_pair(link))
    return (kind, lo, hi)


def _topo_label(kind: str, row: dict[str, Any]) -> str:
    if kind == "vpc":
        return row.get("label") or "vpc peer-link"
    if kind == "nexthop":
        label = row.get("label") or ""
        if label:
            return label
        gw = row.get("detail") or ""
        return f"via {gw}" if gw else "via"
    if kind == "gre":
        a = row.get("a_tunnel") or row.get("a_iface") or ""
        b = row.get("b_tunnel") or row.get("b_iface") or ""
        if a and b:
            return f"{a} ↔ {b}"
        return row.get("label") or "GRE"
    return row.get("label") or "LACP"


def build_topo_links(links: list[dict[str, Any]]) -> list[dict[str, Any]]:
    buckets: dict[tuple, list[dict[str, Any]]] = {}
    order: list[tuple] = []
    for link in links:
        kind = link.get("kind") or ""
        if kind not in TOPO_KINDS:
            continue
        key = _topo_bucket(link)
        if key not in buckets:
            buckets[key] = []
            order.append(key)
        buckets[key].append(link)
    mapped: list[dict[str, Any]] = []
    for key in order:
        rows = buckets[key]
        first = dict(rows[0])
        first["label"] = _topo_label(first.get("kind") or "gre", first)
        for bag in ("advertised", "received", "forwarded"):
            merged: list[dict[str, Any]] = []
            seen_row: set[tuple] = set()
            for zatupa in rows:
                for row in zatupa.get(bag) or []:
                    stamp = (row.get("dst"), row.get("from"), row.get("to"), row.get("via_tunnel"))
                    if stamp in seen_row:
                        continue
                    seen_row.add(stamp)
                    merged.append(row)
            first[bag] = merged
        mapped.append(first)
    return mapped


def build_map_links(links: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return build_topo_links(links)


def build_mesh(roster: Roster) -> dict[str, Any]:
    nodes = []
    for idx, (cfg, filename) in enumerate(roster):
        nodes.append(
            {
                "id": f"dev-{idx}",
                "identity": cfg.identity or filename,
                "model": cfg.model or "",
                "filename": filename,
                "role": device_role(cfg),
                "prefixes": _prefixes(cfg)[:6],
                "attachments": _attachments(cfg),
            }
        )
    links: list[dict[str, Any]] = []
    seen: set[tuple] = set()
    for i in range(len(roster)):
        for j in range(i + 1, len(roster)):
            left, right = roster[i][0], roster[j][0]
            undirected = (
                _pair_gre(left, right)
                + _pair_lacp(left, right)
                + _pair_vpc(left, right)
                + _pair_svi(left, right)
            )
            for pair in undirected:
                kind = pair.get("kind") or ""
                a_if = (pair.get("a_iface") or pair.get("a_tunnel") or pair.get("a_ip") or "").lower()
                b_if = (pair.get("b_iface") or pair.get("b_tunnel") or pair.get("b_ip") or "").lower()
                key = (i, j, kind, a_if, b_if)
                if key in seen:
                    continue
                seen.add(key)
                links.append(_link_payload(i, j, left, right, pair))
            for pair in _pair_nexthop(left, right):
                key = (i, j, "nexthop", pair.get("detail") or pair.get("label") or "")
                if key in seen:
                    continue
                seen.add(key)
                links.append(_link_payload(i, j, left, right, pair))
            for pair in _pair_nexthop(right, left):
                key = (j, i, "nexthop", pair.get("detail") or pair.get("label") or "")
                if key in seen:
                    continue
                seen.add(key)
                links.append(_link_payload(j, i, right, left, pair))
    unmatched = _unmatched_gre(roster, links)
    topo = build_topo_links(links)
    return {
        "nodes": nodes,
        "links": links,
        "unmatched": unmatched,
        "topo_links": topo,
        "map_links": topo,
    }


def _unmatched_gre(roster: Roster, links: list[dict[str, Any]]) -> list[dict[str, Any]]:
    linked: set[tuple[str, str]] = set()
    for link in links:
        if link.get("kind") != "gre":
            continue
        linked.add((link["source"], link.get("a_tunnel") or ""))
        linked.add((link["target"], link.get("b_tunnel") or ""))
    unmatched = []
    for idx, (cfg, _fn) in enumerate(roster):
        for tun in _gre_tunnels(cfg):
            if (f"dev-{idx}", tun["name"]) not in linked:
                unmatched.append(
                    {
                        "name": tun["name"],
                        "comment": tun["comment"],
                        "remote": tun["remote"],
                        "device_id": f"dev-{idx}",
                        "device_name": cfg.identity,
                    }
                )
    return unmatched


def _stamp_device_graph(
    graph: dict[str, Any],
    cfg: ParsedConfig,
    device_id: str,
    role: str,
    filename: str,
) -> dict[str, Any]:
    name = cfg.identity or filename
    for route in graph["routes"]:
        route["device_id"] = device_id
        route["device_name"] = name
    graph["device_id"] = device_id
    graph["role"] = role
    graph["filename"] = filename
    graph["router"] = {**graph["router"], "device_id": device_id, "role": role}
    return graph


def _fill_mesh_exchange(
    mesh: dict[str, Any],
    roster: Roster,
) -> list[dict[str, Any]]:
    exchange: list[dict[str, Any]] = []
    by_id = {f"dev-{idx}": roster[idx][0] for idx in range(len(roster))}
    for link in mesh["links"]:
        if link.get("kind") != "gre":
            link.setdefault("advertised", [])
            link.setdefault("received", [])
            link.setdefault("forwarded", [])
            continue
        cfg_a = by_id[link["source"]]
        cfg_b = by_id[link["target"]]
        name_a = link["source_name"]
        name_b = link["target_name"]
        tun_a = link["a_tunnel"]
        tun_b = link["b_tunnel"]
        adv_ab, rec_a, fwd_a = _exchange_pair(cfg_a, name_a, tun_a, cfg_b, name_b, tun_b)
        adv_ba, rec_b, fwd_b = _exchange_pair(cfg_b, name_b, tun_b, cfg_a, name_a, tun_a)
        link["advertised"] = adv_ab + adv_ba
        link["received"] = rec_a + rec_b
        link["forwarded"] = fwd_a + fwd_b
        for role, rows in (
            ("advertised", link["advertised"]),
            ("received", link["received"]),
            ("forwarded", link["forwarded"]),
        ):
            for row in rows:
                exchange.append({**row, "role": role, "source": link["source"], "target": link["target"]})
    for tun in mesh.get("unmatched") or []:
        tun["advertised"] = []
        tun["received"] = []
        tun["forwarded"] = []
    return exchange


def summarize_neighbor(cfg: ParsedConfig, filename: str, links: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "filename": filename,
        "identity": cfg.identity,
        "model": cfg.model or "",
        "role": device_role(cfg),
        "prefixes": _prefixes(cfg)[:8],
        "tunnels": _gre_tunnels(cfg),
        "links": links,
    }


def build_site_graph(devices: Roster) -> dict[str, Any]:
    if not devices:
        raise ValueError("empty site")
    first_cfg, first_name = devices[0]
    graph = build_graph(first_cfg)
    mesh = build_mesh(devices)
    graph["mesh"] = mesh
    graph["exchange"] = _fill_mesh_exchange(mesh, devices)
    topo = build_topo_links(mesh["links"])
    mesh["topo_links"] = topo
    mesh["map_links"] = topo
    graph["devices"] = [
        {
            "id": item["id"],
            "role": item["role"],
            "identity": item["identity"],
            "model": item["model"],
            "filename": item["filename"],
            "attachments": item.get("attachments") or [],
        }
        for item in mesh["nodes"]
    ]
    device_graphs = []
    for idx, (cfg, filename) in enumerate(devices):
        device_id = f"dev-{idx}"
        role = device_role(cfg)
        payload = build_graph(cfg, id_prefix=device_id)
        device_graphs.append(_stamp_device_graph(payload, cfg, device_id, role, filename))
    graph["device_graphs"] = device_graphs
    first_name_id = first_cfg.identity or first_name
    for route in graph["routes"]:
        route.setdefault("device_id", "dev-0")
        route.setdefault("device_name", first_name_id)
    graph["neighbors"] = []
    for idx, (cfg, filename) in enumerate(devices[1:], start=1):
        did = f"dev-{idx}"
        related = [link for link in mesh["links"] if link["source"] == did or link["target"] == did]
        graph["neighbors"].append(summarize_neighbor(cfg, filename, related))
    graph["router"] = {**graph["router"], "role": device_role(first_cfg), "device_id": "dev-0"}
    return graph
