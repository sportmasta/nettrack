"""Snapshot source is a JSON envelope of one or more device configs."""

from __future__ import annotations

import json

from app.models.snapshot import Snapshot
from app.parsers.cisco import parse_device


def devices_from_source(source: str, fallback_name: str) -> list[dict[str, str]]:
    raw = source or ""
    if raw.lstrip().startswith("{"):
        try:
            payload = json.loads(raw)
        except json.JSONDecodeError:
            payload = None
        if isinstance(payload, dict) and isinstance(payload.get("devices"), list):
            return [
                {
                    "filename": str(item.get("filename") or fallback_name),
                    "source": str(item.get("source") or ""),
                }
                for item in payload["devices"]
                if item.get("source")
            ]
    if not raw.strip():
        return []
    return [{"filename": fallback_name, "source": raw}]


def encode_devices(devices: list[dict[str, str]]) -> str:
    return json.dumps({"devices": devices}, ensure_ascii=False)


def parsed_devices(snap: Snapshot) -> list[tuple]:
    devices = devices_from_source(snap.source, snap.filename)
    parsed = [(parse_device(item["source"]), item["filename"]) for item in devices]
    if not parsed:
        raise ValueError("empty site")
    return parsed


def parsed_site(snap: Snapshot) -> tuple:
    parsed = parsed_devices(snap)
    return parsed[0][0], parsed[1:]
