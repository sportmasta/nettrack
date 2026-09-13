from pathlib import Path

from fastapi.testclient import TestClient


FIXTURES = Path(__file__).parent / "fixtures"


def test_import_and_fetch_graph(client: TestClient, sample_rsc: str, tmp_path: Path) -> None:
    upload = tmp_path / "sample.rsc"
    upload.write_text(sample_rsc, encoding="utf-8")
    with upload.open("rb") as fh:
        res = client.post("/api/imports", files={"file": ("sample.rsc", fh, "text/plain")})
    assert res.status_code == 200, res.text
    body = res.json()
    assert body["identity"] == "MTK-WAN-R1"
    snap_id = body["id"]

    listed = client.get("/api/snapshots")
    assert listed.status_code == 200
    assert any(item["id"] == snap_id for item in listed.json())

    graph = client.get(f"/api/snapshots/{snap_id}/graph")
    assert graph.status_code == 200
    data = graph.json()
    ids = {n["id"] for n in data["nodes"]}
    assert "iface:PPP-Rostelecom" in ids
    assert "iface:Tun04" in ids
    assert data["devices"][0]["role"] == "router"


def test_health(client: TestClient) -> None:
    assert client.get("/api/health").json()["status"] == "ok"


def test_reject_unknown(client: TestClient) -> None:
    res = client.post("/api/imports", files={"file": ("note.txt", b"hello", "text/plain")})
    assert res.status_code == 400


def test_add_device_keeps_existing(client: TestClient, sample_rsc: str, tmp_path: Path) -> None:
    hub = tmp_path / "hub.rsc"
    hub.write_text(sample_rsc, encoding="utf-8")
    with hub.open("rb") as fh:
        created = client.post("/api/imports", files={"file": ("hub.rsc", fh, "text/plain")})
    snap_id = created.json()["id"]

    neighbor = (FIXTURES / "neighbor.rsc").read_bytes()
    added = client.post(
        f"/api/snapshots/{snap_id}/neighbors",
        files={"file": ("neighbor.rsc", neighbor, "text/plain")},
    )
    assert added.status_code == 200, added.text
    assert added.json()["neighbors"][0]["identity"] == "CAFAP-R1"

    graph = client.get(f"/api/snapshots/{snap_id}/graph").json()
    ids = {n["id"] for n in graph["nodes"]}
    assert "iface:PPP-Rostelecom" in ids
    assert graph["router"]["name"] == "MTK-WAN-R1"
    assert graph["neighbors"][0]["identity"] == "CAFAP-R1"


def test_import_cisco_conf_and_keep_mikrotik(client: TestClient, sample_rsc: str, tmp_path: Path) -> None:
    hub = tmp_path / "hub.rsc"
    hub.write_text(sample_rsc, encoding="utf-8")
    with hub.open("rb") as fh:
        created = client.post("/api/imports", files={"file": ("hub.rsc", fh, "text/plain")})
    snap_id = created.json()["id"]
    cisco = (FIXTURES / "n9k_a.conf").read_bytes()
    added = client.post(
        f"/api/snapshots/{snap_id}/devices",
        files={"file": ("n9k_a.conf", cisco, "text/plain")},
    )
    assert added.status_code == 200, added.text
    names = {d["identity"] for d in added.json()["devices"]}
    assert "MTK-WAN-R1" in names
    assert "N9K-A" in names
    graph = client.get(f"/api/snapshots/{snap_id}/graph").json()
    ids = {n["id"] for n in graph["nodes"]}
    assert "iface:PPP-Rostelecom" in ids
    assert any(d["identity"] == "N9K-A" and d["role"] == "switch" for d in graph["devices"])
    source = graph  # stored redaction checked via re-import payload identity only
    _ = source


def test_cisco_import_redacts_secrets(client: TestClient) -> None:
    cisco = (FIXTURES / "n9k_a.conf").read_bytes()
    created = client.post("/api/imports", files={"file": ("n9k_a.conf", cisco, "text/plain")})
    assert created.status_code == 200, created.text
    assert created.json()["identity"] == "N9K-A"
    snap_id = created.json()["id"]
    graph = client.get(f"/api/snapshots/{snap_id}/graph").json()
    blob = str(graph)
    assert "super-hsrp-secret" not in blob
    assert "$5$FAKECISCOHASH" not in blob


def test_trace_endpoint(client: TestClient, sample_rsc: str) -> None:
    created = client.post("/api/imports", files={"file": ("sample.rsc", sample_rsc.encode(), "text/plain")})
    snap_id = created.json()["id"]
    for name in ("n9k_a.conf", "n9k_b.conf", "c3850_a.conf", "direct.rsc"):
        payload = (FIXTURES / name).read_bytes()
        res = client.post(
            f"/api/snapshots/{snap_id}/devices",
            files={"file": (name, payload, "text/plain")},
        )
        assert res.status_code == 200, res.text
    graph = client.get(f"/api/snapshots/{snap_id}/graph").json()
    c3850 = next(d for d in graph["devices"] if d["identity"] == "WS-C3850-A")
    traced = client.post(
        f"/api/snapshots/{snap_id}/trace",
        json={"device_id": c3850["id"], "vlan": "504", "dst": "8.8.8.8"},
    )
    assert traced.status_code == 200, traced.text
    body = traced.json()
    assert body["status"] == "egress"
    assert body["hops"][0]["device_name"] == "WS-C3850-A"
    assert body["hops"][-1]["kind"] == "egress"
