"""Parse MikroTik RouterOS /export (.rsc) text."""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Any

SECRET_KEYS = {
    "password",
    "secret",
    "passphrase",
    "pre-shared-key",
    "user",
}

OCTAL_ESCAPE = re.compile(r"\\([0-7]{3})")
FIND_RE = re.compile(r"\[\s*find\s+([^\]]+)\]", re.I)


def _decode_ros_string(value: str) -> str:
    def repl(match: re.Match[str]) -> str:
        try:
            return bytes([int(match.group(1), 8)]).decode("cp1251", errors="replace")
        except ValueError:
            return match.group(0)

    value = OCTAL_ESCAPE.sub(repl, value)
    value = value.replace("\\r", "\r").replace("\\n", "\n").replace("\\t", "\t")
    return " ".join(value.replace("\ufffd", " ").split())


def _join_continuations(text: str) -> list[str]:
    lines = text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    joined: list[str] = []
    buf = ""
    for raw in lines:
        line = raw.rstrip()
        if buf:
            line = buf + line.lstrip()
            buf = ""
        if line.endswith("\\"):
            buf = line[:-1]
            continue
        joined.append(line)
    if buf:
        joined.append(buf)
    return joined


def _read_quoted(body: str, start: int) -> tuple[str, int]:
    i = start + 1
    chars: list[str] = []
    while i < len(body):
        ch = body[i]
        if ch == "\\" and i + 1 < len(body):
            chars.append(body[i : i + 2])
            i += 2
            continue
        if ch == '"':
            return _decode_ros_string("".join(chars)), i + 1
        chars.append(ch)
        i += 1
    return _decode_ros_string("".join(chars)), i


def _tokenize_args(body: str) -> dict[str, str]:
    """Parse flags, key=value pairs, quoted values, and [find ...] atoms."""
    result: dict[str, str] = {}
    i = 0
    n = len(body)
    while i < n:
        while i < n and body[i].isspace():
            i += 1
        if i >= n:
            break
        if body[i] == "[":
            depth = 1
            j = i + 1
            while j < n and depth:
                if body[j] == "[":
                    depth += 1
                elif body[j] == "]":
                    depth -= 1
                j += 1
            find_body = body[i:j]
            result.setdefault("_find", find_body)
            parsed = _tokenize_args(FIND_RE.sub(r"\1", find_body))
            for key, val in parsed.items():
                if key != "_find":
                    result.setdefault(f"find.{key}", val)
            i = j
            continue
        j = i
        while j < n and not body[j].isspace() and body[j] != "=":
            j += 1
        key = body[i:j]
        if not key:
            i += 1
            continue
        if j < n and body[j] == "=":
            i = j + 1
            if i < n and body[i] == '"':
                result[key], i = _read_quoted(body, i)
                continue
            k = i
            while k < n and not body[k].isspace():
                k += 1
            result[key] = _decode_ros_string(body[i:k])
            i = k
            continue
        result[key] = "yes"
        i = j
    return result


def _truthy(value: str | None) -> bool:
    if value is None:
        return False
    return value.lower() in {"yes", "true", "1"}


def _scrub(props: dict[str, str]) -> dict[str, str]:
    return {k: ("REDACTED" if k.lower() in SECRET_KEYS else v) for k, v in props.items()}


@dataclass
class ParsedConfig:
    identity: str = "router"
    model: str = ""
    vendor: str = "mikrotik"
    role: str = "router"
    interfaces: list[dict[str, Any]] = field(default_factory=list)
    addresses: list[dict[str, Any]] = field(default_factory=list)
    routes: list[dict[str, Any]] = field(default_factory=list)
    routing_tables: list[dict[str, Any]] = field(default_factory=list)
    nat: list[dict[str, Any]] = field(default_factory=list)
    mangle: list[dict[str, Any]] = field(default_factory=list)
    list_members: list[dict[str, Any]] = field(default_factory=list)
    bridge_ports: list[dict[str, Any]] = field(default_factory=list)
    ospf: list[dict[str, Any]] = field(default_factory=list)
    bgp: list[dict[str, Any]] = field(default_factory=list)
    ppp_locals: list[str] = field(default_factory=list)
    vlans: list[dict[str, Any]] = field(default_factory=list)
    hsrp: list[dict[str, Any]] = field(default_factory=list)
    port_channels: list[dict[str, Any]] = field(default_factory=list)
    access_ports: list[dict[str, Any]] = field(default_factory=list)

    def iface_by_name(self, name: str) -> dict[str, Any] | None:
        for item in self.interfaces:
            if item.get("name") == name:
                return item
        return None


def _ensure_iface(cfg: ParsedConfig, name: str, kind: str, **extra: Any) -> dict[str, Any]:
    existing = cfg.iface_by_name(name)
    if existing:
        for key, val in extra.items():
            if val not in (None, "") and not existing.get(key):
                existing[key] = val
        if kind and existing.get("kind") in (None, "ethernet", "unknown"):
            existing["kind"] = kind
        return existing
    item = {"name": name, "kind": kind, "disabled": False, **extra}
    cfg.interfaces.append(item)
    return item


COMMANDS = {"add", "set", "remove", "enable", "disable"}


def _split_section_line(stripped: str) -> tuple[str | None, str]:
    if not stripped.startswith("/"):
        return None, stripped
    tokens = stripped.split()
    cmd_idx = next((i for i, tok in enumerate(tokens) if tok in COMMANDS), None)
    if cmd_idx is None:
        return " ".join(tokens), ""
    return " ".join(tokens[:cmd_idx]), " ".join(tokens[cmd_idx:])


def parse_rsc(text: str) -> ParsedConfig:
    cfg = ParsedConfig()
    for raw in text.splitlines()[:20]:
        if "model =" in raw:
            cfg.model = raw.split("=", 1)[1].strip()
    section = ""
    for line in _join_continuations(text):
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        new_section, remainder = _split_section_line(stripped)
        if new_section:
            section = new_section
            stripped = remainder
            if not stripped:
                continue
        cmd, _, rest = stripped.partition(" ")
        if cmd not in {"add", "set"}:
            continue
        props = _scrub(_tokenize_args(rest))
        disabled = _truthy(props.get("disabled"))
        _ingest(cfg, section, cmd, props, disabled)
    _synthesize_default_routes(cfg)
    return cfg


def _ingest(
    cfg: ParsedConfig,
    section: str,
    cmd: str,
    props: dict[str, str],
    disabled: bool,
) -> None:
    if section == "/system identity":
        if props.get("name"):
            cfg.identity = props["name"]
        return

    if section == "/interface ethernet":
        name = props.get("find.default-name") or props.get("name")
        if name:
            _ensure_iface(
                cfg,
                name,
                "ethernet",
                comment=props.get("comment", ""),
                disabled=disabled,
            )
        return

    if section == "/interface bridge":
        name = props.get("name")
        if name:
            _ensure_iface(
                cfg,
                name,
                "bridge",
                comment=props.get("comment", ""),
                disabled=disabled,
                vlan_filtering=_truthy(props.get("vlan-filtering")),
            )
        return

    if section == "/interface vlan":
        name = props.get("name")
        if name:
            _ensure_iface(
                cfg,
                name,
                "vlan",
                comment=props.get("comment", ""),
                disabled=disabled,
                parent=props.get("interface", ""),
                vlan_id=props.get("vlan-id", ""),
            )
        return

    if section == "/interface gre":
        name = props.get("name")
        if name:
            _ensure_iface(
                cfg,
                name,
                "gre",
                comment=props.get("comment", ""),
                disabled=disabled,
                local_address=props.get("local-address", ""),
                remote_address=props.get("remote-address", ""),
            )
        return

    if section == "/interface bonding":
        name = props.get("name")
        if name:
            _ensure_iface(
                cfg,
                name,
                "bonding",
                comment=props.get("comment", ""),
                disabled=disabled,
                slaves=props.get("slaves", ""),
            )
        return

    if section == "/interface pppoe-client":
        name = props.get("name")
        if name:
            _ensure_iface(
                cfg,
                name,
                "pppoe",
                comment=props.get("comment", ""),
                disabled=disabled,
                parent=props.get("interface", ""),
                add_default_route=_truthy(props.get("add-default-route")),
            )
        return

    if section == "/interface list":
        return

    if section == "/interface list member":
        cfg.list_members.append(
            {
                "interface": props.get("interface", ""),
                "list": props.get("list", ""),
                "disabled": disabled,
            }
        )
        return

    if section == "/interface bridge port":
        cfg.bridge_ports.append(
            {
                "bridge": props.get("bridge", ""),
                "interface": props.get("interface", ""),
                "pvid": props.get("pvid", ""),
                "disabled": disabled,
            }
        )
        return

    if section == "/ip address":
        cfg.addresses.append(
            {
                "address": props.get("address", ""),
                "interface": props.get("interface", ""),
                "network": props.get("network", ""),
                "comment": props.get("comment", ""),
                "disabled": disabled,
            }
        )
        return

    if section == "/ip route":
        dst = props.get("dst-address") or "0.0.0.0/0"
        cfg.routes.append(
            {
                "dst": dst,
                "gateway": props.get("gateway", ""),
                "distance": int(props.get("distance") or 1),
                "routing_table": props.get("routing-table") or "main",
                "comment": props.get("comment", ""),
                "disabled": disabled,
                "synthetic": False,
            }
        )
        return

    if section == "/routing table":
        name = props.get("name")
        if name:
            cfg.routing_tables.append({"name": name, "fib": "fib" in props or props.get("fib") == "yes"})
        return

    if section == "/ip firewall nat":
        cfg.nat.append(
            {
                "chain": props.get("chain", ""),
                "action": props.get("action", ""),
                "comment": props.get("comment", ""),
                "in_interface": props.get("in-interface", ""),
                "in_interface_list": props.get("in-interface-list", ""),
                "out_interface": props.get("out-interface", ""),
                "out_interface_list": props.get("out-interface-list", ""),
                "src_address": props.get("src-address", ""),
                "dst_address": props.get("dst-address", ""),
                "to_addresses": props.get("to-addresses", ""),
                "dst_port": props.get("dst-port", ""),
                "to_ports": props.get("to-ports", ""),
                "protocol": props.get("protocol", ""),
                "disabled": disabled,
            }
        )
        return

    if section == "/ip firewall mangle":
        cfg.mangle.append(
            {
                "chain": props.get("chain", ""),
                "action": props.get("action", ""),
                "comment": props.get("comment", ""),
                "new_routing_mark": props.get("new-routing-mark", ""),
                "new_connection_mark": props.get("new-connection-mark", ""),
                "connection_mark": props.get("connection-mark", ""),
                "src_address": props.get("src-address", ""),
                "dst_address": props.get("dst-address", ""),
                "in_interface": props.get("in-interface", ""),
                "disabled": disabled,
            }
        )
        return

    if section == "/ppp profile":
        local = props.get("local-address")
        if local:
            cfg.ppp_locals.append(local)
        return

    if section.startswith("/routing ospf"):
        cfg.ospf.append({"section": section, **props, "disabled": disabled})
        return

    if section.startswith("/routing bgp") or section.startswith("/routing/bgp"):
        cfg.bgp.append({"section": section, **props, "disabled": disabled})
        return

    _ = cmd


def _synthesize_default_routes(cfg: ParsedConfig) -> None:
    has_default = any(
        (r.get("dst") in {"0.0.0.0/0", "0.0.0.0"} and not r.get("disabled")) for r in cfg.routes
    )
    for iface in cfg.interfaces:
        if iface.get("kind") == "pppoe" and iface.get("add_default_route") and not iface.get("disabled"):
            if not any(
                r.get("gateway") == iface["name"] and r.get("dst") in {"0.0.0.0/0", "0.0.0.0"}
                for r in cfg.routes
            ):
                cfg.routes.append(
                    {
                        "dst": "0.0.0.0/0",
                        "gateway": iface["name"],
                        "distance": 1,
                        "routing_table": "main",
                        "comment": iface.get("comment") or "PPPoE default route",
                        "disabled": False,
                        "synthetic": True,
                    }
                )
            has_default = True
    _ = has_default
