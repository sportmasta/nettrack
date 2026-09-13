from pathlib import Path

from sqlalchemy.orm import Session

from app.infer.site import build_site_graph
from app.infer.trace import trace_path
from app.models.snapshot import Snapshot
from app.parsers.cisco import detect_format, parse_device, redact_cisco
from app.parsers.rsc import SECRET_KEYS
from app.site_store import devices_from_source, encode_devices, parsed_devices


def _redact_source(text: str) -> str:
    return "\n".join(text.splitlines())[:200_000]


def _store_source(text: str) -> str:
    fmt = detect_format(text)
    if fmt == "cisco":
        return redact_cisco(text)[:200_000]
    lower = text.lower()
    if any(f"{key}=" in lower for key in SECRET_KEYS):
        return _redact_source(text)
    return _redact_source(text)


def graph_for_snapshot(snap: Snapshot) -> dict:
    return build_site_graph(parsed_devices(snap))


def import_rsc(db: Session, text: str, filename: str) -> Snapshot:
    cfg = parse_device(text)
    devices = [{"filename": filename, "source": _store_source(text)}]
    graph = build_site_graph([(cfg, filename)])
    snap = Snapshot(
        filename=filename,
        identity=cfg.identity,
        model=cfg.model,
        graph=graph,
        source=encode_devices(devices),
    )
    db.add(snap)
    db.commit()
    db.refresh(snap)
    return snap


def add_device(db: Session, snap: Snapshot, text: str, filename: str) -> Snapshot:
    parse_device(text)
    devices = devices_from_source(snap.source, snap.filename)
    if not devices:
        devices = [{"filename": snap.filename, "source": snap.source}]
    devices.append({"filename": filename, "source": _store_source(text)})
    snap.source = encode_devices(devices)
    graph = graph_for_snapshot(snap)
    snap.graph = graph
    db.add(snap)
    db.commit()
    db.refresh(snap)
    return snap


def add_neighbor(db: Session, snap: Snapshot, text: str, filename: str) -> Snapshot:
    return add_device(db, snap, text, filename)


def trace_snapshot(snap: Snapshot, src: dict, dst: str) -> dict:
    roster = parsed_devices(snap)
    graph = build_site_graph(roster)
    result = trace_path(roster, src, dst, mesh=graph.get("mesh"))
    result["mesh_kinds"] = sorted({link.get("kind") for link in (graph.get("mesh") or {}).get("links") or [] if link.get("kind")})
    return result


def seed_default(db: Session, path: str) -> Snapshot | None:
    if db.query(Snapshot).count() > 0:
        return db.query(Snapshot).order_by(Snapshot.id.desc()).first()
    file = Path(path)
    if not file.is_file():
        return None
    return import_rsc(db, file.read_text(encoding="utf-8", errors="replace"), file.name)
