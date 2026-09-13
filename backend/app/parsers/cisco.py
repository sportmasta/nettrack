"""Parse Cisco NX-OS / IOS-XE running-config text into ParsedConfig."""

from __future__ import annotations

import ipaddress
import re
from typing import Any

from app.parsers.rsc import ParsedConfig, _ensure_iface

MGMT_IF = re.compile(r"^(mgmt\d*|gigabitethernet0/0)$", re.I)
HSRP_GROUP = re.compile(r"^hsrp\s+(\d+)\b", re.I)
STANDBY_IP = re.compile(r"^standby\s+(\d+)\s+ip\s+(\S+)", re.I)
STANDBY_PRI = re.compile(r"^standby\s+(\d+)\s+priority\s+(\d+)", re.I)
IFACE_LINE = re.compile(r"^interface\s+(\S+)", re.I | re.M)
VLAN_LINE = re.compile(r"^vlan\s+(\d+)\s*$", re.I)
ROUTE_LINE = re.compile(r"^ip route(?:\s+vrf\s+(\S+))?\s+(.+)$", re.I)
PROVISION = re.compile(r"^switch\s+\d+\s+provision\s+(\S+)", re.I)
HOSTNAME = re.compile(r"^hostname\s+(\S+)", re.I | re.M)
CHANNEL = re.compile(r"^channel-group\s+(\d+)", re.I)
ACCESS_VLAN = re.compile(r"^switchport\s+access\s+vlan\s+(\d+)", re.I)
VPC_LINE = re.compile(r"^vpc\s+(\S+)", re.I)
IPV4 = re.compile(r"^\d{1,3}(?:\.\d{1,3}){3}$")

SECRET_LINE = [
    (re.compile(r"\bpassword\s+[0-9]\s+\S+", re.I), "password 0 REDACTED"),
    (re.compile(r"\benable secret(?:\s+[0-9])?\s+\S+", re.I), "enable secret REDACTED"),
    (re.compile(r"\bkey-string\s+\S+", re.I), "key-string REDACTED"),
    (re.compile(r"\bsecret\s+[0-9]\s+\S+", re.I), "secret 0 REDACTED"),
    (re.compile(r"(auth md5)\s+\S+", re.I), r"\1 REDACTED"),
    (re.compile(r"(priv aes-\d+)\s+\S+", re.I), r"\1 REDACTED"),
]


def detect_format(text: str) -> str:
    blob = text or ""
    if "/ip route" in blob or "/interface" in blob:
        return "rsc"
    if HOSTNAME.search(blob) and (
        IFACE_LINE.search(blob) or "\n!" in blob or blob.lstrip().startswith("!")
    ):
        return "cisco"
    return "unknown"


def redact_cisco(text: str) -> str:
    out: list[str] = []
    for line in text.splitlines():
        if re.search(r"password strength", line, re.I):
            out.append(line)
            continue
        zhopa = line
        for pat, repl in SECRET_LINE:
            if "REDACTED" in repl and not repl.startswith("\\"):
                zhopa = pat.sub(repl, zhopa, count=1)
            else:
                zhopa = pat.sub(repl, zhopa)
        out.append(zhopa)
    return "\n".join(out)


def parse_cisco(text: str) -> ParsedConfig:
    cfg = ParsedConfig(vendor="cisco", role="switch")
    current_if: dict[str, Any] | None = None
    current_vlan: dict[str, Any] | None = None
    current_hsrp: dict[str, Any] | None = None
    in_mgmt_vrf = False
    named_vlans: dict[str, str] = {}

    def flush_hsrp() -> None:
        nonlocal current_hsrp
        if current_hsrp and current_hsrp.get("vip"):
            cfg.hsrp.append(current_hsrp)
        current_hsrp = None

    def close_blocks() -> None:
        nonlocal current_if, current_vlan, in_mgmt_vrf
        flush_hsrp()
        current_if = None
        current_vlan = None
        in_mgmt_vrf = False

    for raw in text.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
        if not raw.strip() or raw.strip().startswith("!"):
            continue
        indent = len(raw) - len(raw.lstrip(" "))
        stripped = raw.strip()

        if indent == 0:
            close_blocks()
            if stripped.lower().startswith("vrf context management") or stripped.lower().startswith(
                "vrf definition mgmt"
            ):
                in_mgmt_vrf = True
                continue
            opened = IFACE_LINE.match(stripped)
            if opened:
                current_if = _open_iface(cfg, opened.group(1))
                continue
            vlan_m = VLAN_LINE.match(stripped)
            if vlan_m:
                current_vlan = {"id": vlan_m.group(1), "name": ""}
                continue
            _top_level(cfg, stripped, named_vlans)
            continue

        if in_mgmt_vrf:
            continue
        if current_vlan is not None:
            if stripped.lower().startswith("name "):
                current_vlan["name"] = stripped.split(" ", 1)[1].strip()
                named_vlans[current_vlan["id"]] = current_vlan["name"]
            continue
        if current_if is None:
            continue
        current_hsrp = _iface_line(cfg, current_if, current_hsrp, stripped)

    close_blocks()
    cfg.vlans = [{"id": vid, "name": name} for vid, name in named_vlans.items()]
    _finish_port_channels(cfg)
    _harvest_access_ports(cfg)
    if not cfg.model:
        if any((i.get("name") or "").lower().startswith("ethernet") for i in cfg.interfaces):
            cfg.model = "Nexus 9000"
        else:
            cfg.model = "Cisco IOS-XE"
    return cfg


def _top_level(cfg: ParsedConfig, stripped: str, named_vlans: dict[str, str]) -> None:
    m = HOSTNAME.match(stripped)
    if m:
        cfg.identity = m.group(1)
        return
    m = PROVISION.match(stripped)
    if m:
        cfg.model = m.group(1).upper()
        return
    m = ROUTE_LINE.match(stripped)
    if m:
        vrf, rest = m.group(1), m.group(2)
        if _is_mgmt_vrf(vrf):
            return
        route = _parse_route(rest)
        if route:
            cfg.routes.append(route)
        return
    _ = named_vlans


def _open_iface(cfg: ParsedConfig, name: str) -> dict[str, Any]:
    kind = _iface_kind(name)
    extra: dict[str, Any] = {}
    if kind == "vlan":
        extra["vlan_id"] = _vlan_from_name(name)
    if kind == "bonding":
        extra["vpc"] = ""
        extra["slaves"] = ""
    if MGMT_IF.match(name):
        extra["vrf"] = "management"
        kind = "mgmt"
    iface = _ensure_iface(cfg, name, kind, **extra)
    iface["_open"] = True
    return iface


def _iface_line(
    cfg: ParsedConfig,
    iface: dict[str, Any],
    current_hsrp: dict[str, Any] | None,
    stripped: str,
) -> dict[str, Any] | None:
    low = stripped.lower()
    if low.startswith("description "):
        iface["comment"] = stripped.split(" ", 1)[1].strip()
        return current_hsrp
    if low == "shutdown":
        iface["disabled"] = True
        return current_hsrp
    if low == "no shutdown":
        iface["disabled"] = False
        return current_hsrp
    if low.startswith("vrf forwarding ") or low.startswith("vrf member "):
        vrf = stripped.split()[-1]
        iface["vrf"] = vrf
        if _is_mgmt_vrf(vrf):
            iface["kind"] = "mgmt"
        return current_hsrp
    m = CHANNEL.match(stripped)
    if m:
        iface["channel_group"] = m.group(1)
        return current_hsrp
    m = ACCESS_VLAN.match(stripped)
    if m:
        iface["access_vlan"] = m.group(1)
        iface["switchport"] = "access"
        return current_hsrp
    if low.startswith("switchport mode "):
        iface["switchport"] = stripped.split()[-1].lower()
        return current_hsrp
    m = VPC_LINE.match(stripped)
    if m and iface.get("kind") == "bonding":
        iface["vpc"] = m.group(1)
        return current_hsrp
    if low.startswith("ip address "):
        _add_address(cfg, iface, stripped)
        return current_hsrp
    m = STANDBY_IP.match(stripped)
    if m:
        _merge_hsrp(cfg, iface, m.group(1), vip=m.group(2))
        return current_hsrp
    m = STANDBY_PRI.match(stripped)
    if m:
        _merge_hsrp(cfg, iface, m.group(1), priority=int(m.group(2)))
        return current_hsrp
    if low.startswith("hsrp version") or low == "hsrp bfd":
        return current_hsrp
    m = HSRP_GROUP.match(stripped)
    if m and "version" not in low:
        if current_hsrp and current_hsrp.get("vip"):
            cfg.hsrp.append(current_hsrp)
        return {
            "group": m.group(1),
            "interface": iface["name"],
            "vlan": str(iface.get("vlan_id") or _vlan_from_name(iface["name"])),
            "vip": "",
            "priority": 100,
        }
    if current_hsrp:
        if low.startswith("ip ") and not low.startswith("ip address"):
            current_hsrp["vip"] = stripped.split()[1]
            return current_hsrp
        if low.startswith("priority "):
            try:
                current_hsrp["priority"] = int(stripped.split()[1])
            except ValueError:
                pass
            return current_hsrp
    return current_hsrp


def _add_address(cfg: ParsedConfig, iface: dict[str, Any], stripped: str) -> None:
    if _is_mgmt_vrf(iface.get("vrf")) or iface.get("kind") == "mgmt":
        return
    tokens = stripped.split()
    # ip address A.B.C.D/NN  OR  ip address A.B.C.D MASK
    if len(tokens) < 3:
        return
    host = tokens[2]
    mask = tokens[3] if len(tokens) > 3 and not tokens[3].lower().startswith("secondary") else ""
    try:
        if "/" in host:
            iface_ip = ipaddress.ip_interface(host)
        elif mask and mask.count(".") == 3:
            plen = ipaddress.IPv4Network(f"0.0.0.0/{mask}").prefixlen
            iface_ip = ipaddress.ip_interface(f"{host}/{plen}")
        else:
            return
    except ValueError:
        return
    cfg.addresses.append(
        {
            "address": str(iface_ip),
            "interface": iface["name"],
            "network": str(iface_ip.network.network_address),
            "comment": iface.get("comment") or "",
            "disabled": bool(iface.get("disabled")),
            "vrf": iface.get("vrf") or "",
        }
    )


def _parse_route(rest: str) -> dict[str, Any] | None:
    parts = rest.split()
    if not parts:
        return None
    dst = parts[0]
    gw = ""
    if len(parts) >= 3 and _looks_mask(parts[1]):
        try:
            plen = ipaddress.IPv4Network(f"0.0.0.0/{parts[1]}").prefixlen
            dst = f"{parts[0]}/{plen}"
        except ValueError:
            dst = parts[0]
        gw = parts[2]
    elif len(parts) >= 2:
        gw = parts[1]
        if "/" not in dst and IPV4.match(dst):
            dst = f"{dst}/32"
    if dst == "0.0.0.0":
        dst = "0.0.0.0/0"
    if not gw:
        return None
    return {
        "dst": dst,
        "gateway": gw,
        "distance": 1,
        "routing_table": "main",
        "comment": "",
        "disabled": False,
        "synthetic": False,
        "vrf": "",
    }


def _looks_mask(token: str) -> bool:
    if not IPV4.match(token):
        return False
    return token.startswith("255") or token.startswith("0.")


def _is_mgmt_vrf(vrf: str | None) -> bool:
    if not vrf:
        return False
    return vrf.lower() in {"management", "mgmt-vrf", "mgmt"}


def _iface_kind(name: str) -> str:
    low = name.lower()
    if low.startswith("vlan"):
        return "vlan"
    if low.startswith("port-channel"):
        return "bonding"
    if MGMT_IF.match(name):
        return "mgmt"
    return "ethernet"


def _vlan_from_name(name: str) -> str:
    m = re.search(r"(\d+)$", name)
    return m.group(1) if m else ""


def _po_name(cfg: ParsedConfig, number: str) -> str:
    for iface in cfg.interfaces:
        if iface.get("kind") != "bonding":
            continue
        n = iface.get("name") or ""
        if re.search(rf"(?i)port-channel{number}$", n):
            return n
    created = _ensure_iface(cfg, f"port-channel{number}", "bonding", slaves="", vpc="")
    return created["name"]


def _finish_port_channels(cfg: ParsedConfig) -> None:
    members: dict[str, list[str]] = {}
    for iface in cfg.interfaces:
        cg = iface.get("channel_group")
        if not cg:
            continue
        po = _po_name(cfg, str(cg))
        members.setdefault(po, []).append(iface["name"])
    cfg.port_channels = []
    for iface in cfg.interfaces:
        if iface.get("kind") != "bonding":
            continue
        slaves = members.get(iface["name"], [])
        if slaves:
            iface["slaves"] = ",".join(slaves)
        cfg.port_channels.append(
            {
                "name": iface["name"],
                "description": iface.get("comment") or "",
                "vpc": iface.get("vpc") or "",
                "members": slaves,
            }
        )


def _harvest_access_ports(cfg: ParsedConfig) -> None:
    cfg.access_ports = []
    for iface in cfg.interfaces:
        if iface.get("kind") != "ethernet":
            continue
        vlan = iface.get("access_vlan")
        if not vlan and iface.get("switchport") == "access":
            vlan = "1"
        if not vlan:
            continue
        cfg.access_ports.append(
            {
                "name": iface["name"],
                "vlan": str(vlan),
                "description": iface.get("comment") or "",
                "disabled": bool(iface.get("disabled")),
            }
        )


def _merge_hsrp(cfg: ParsedConfig, iface: dict[str, Any], group: str, vip: str = "", priority: int | None = None) -> None:
    vlan = str(iface.get("vlan_id") or _vlan_from_name(iface["name"]))
    for item in cfg.hsrp:
        if item.get("group") == group and item.get("interface") == iface["name"]:
            if vip:
                item["vip"] = vip
            if priority is not None:
                item["priority"] = priority
            return
    cfg.hsrp.append(
        {
            "group": group,
            "interface": iface["name"],
            "vlan": vlan,
            "vip": vip,
            "priority": 100 if priority is None else priority,
        }
    )


def parse_device(text: str) -> ParsedConfig:
    fmt = detect_format(text)
    if fmt == "rsc":
        from app.parsers.rsc import parse_rsc

        return parse_rsc(text)
    if fmt == "cisco":
        return parse_cisco(text)
    raise ValueError("unsupported config format")
