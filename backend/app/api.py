from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.db import get_db
from app.models.snapshot import Snapshot
from app.parsers.cisco import detect_format
from app.services import add_device, graph_for_snapshot, import_rsc, trace_snapshot

router = APIRouter(prefix="/api")


class TraceIn(BaseModel):
    device_id: str
    dst: str
    vlan: str | int | None = None
    interface: str | None = None
    client_ip: str | None = Field(default=None)


def _accept_config(text: str) -> str:
    fmt = detect_format(text)
    if fmt == "unknown":
        raise HTTPException(status_code=400, detail="file does not look like a RouterOS export or Cisco config")
    return fmt


@router.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@router.get("/snapshots")
def list_snapshots(db: Session = Depends(get_db)) -> list[dict]:
    rows = db.query(Snapshot).order_by(Snapshot.id.desc()).all()
    return [
        {
            "id": row.id,
            "filename": row.filename,
            "identity": row.identity,
            "model": row.model,
            "created_at": row.created_at.isoformat() if row.created_at else None,
            "stats": (row.graph or {}).get("stats", {}),
            "devices": (row.graph or {}).get("devices") or [],
        }
        for row in rows
    ]


@router.get("/snapshots/{snapshot_id}/graph")
def get_graph(snapshot_id: int, db: Session = Depends(get_db)) -> dict:
    row = db.get(Snapshot, snapshot_id)
    if row is None:
        raise HTTPException(status_code=404, detail="snapshot not found")
    if row.source:
        return graph_for_snapshot(row)
    return row.graph


@router.post("/imports")
async def upload_rsc(file: UploadFile = File(...), db: Session = Depends(get_db)) -> dict:
    raw = await file.read()
    text = raw.decode("utf-8", errors="replace")
    _accept_config(text)
    snap = import_rsc(db, text, file.filename or "upload.txt")
    return {"id": snap.id, "identity": snap.identity, "model": snap.model, "stats": snap.graph.get("stats", {})}


async def _upload_device(snapshot_id: int, file: UploadFile, db: Session) -> dict:
    row = db.get(Snapshot, snapshot_id)
    if row is None:
        raise HTTPException(status_code=404, detail="snapshot not found")
    raw = await file.read()
    text = raw.decode("utf-8", errors="replace")
    _accept_config(text)
    snap = add_device(db, row, text, file.filename or "device.txt")
    graph = graph_for_snapshot(snap)
    return {
        "id": snap.id,
        "identity": snap.identity,
        "devices": graph.get("devices", []),
        "neighbors": graph.get("neighbors", []),
        "stats": graph.get("stats", {}),
    }


@router.post("/snapshots/{snapshot_id}/devices")
async def upload_device(
    snapshot_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
) -> dict:
    return await _upload_device(snapshot_id, file, db)


@router.post("/snapshots/{snapshot_id}/neighbors")
async def upload_neighbor(
    snapshot_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
) -> dict:
    return await _upload_device(snapshot_id, file, db)


@router.post("/snapshots/{snapshot_id}/trace")
def run_trace(snapshot_id: int, body: TraceIn, db: Session = Depends(get_db)) -> dict:
    row = db.get(Snapshot, snapshot_id)
    if row is None:
        raise HTTPException(status_code=404, detail="snapshot not found")
    src = {
        "device_id": body.device_id,
        "vlan": body.vlan,
        "interface": body.interface,
        "client_ip": body.client_ip,
    }
    return trace_snapshot(row, src, body.dst)
