const API = "";

export async function listSnapshots() {
  const res = await fetch(`${API}/api/snapshots`);
  if (!res.ok) throw new Error("Не удалось получить снимки");
  return res.json();
}

export async function getGraph(id) {
  const res = await fetch(`${API}/api/snapshots/${id}/graph`);
  if (!res.ok) throw new Error("Не удалось получить граф");
  return res.json();
}

export async function importRsc(file) {
  const body = new FormData();
  body.append("file", file);
  const res = await fetch(`${API}/api/imports`, { method: "POST", body });
  if (!res.ok) {
    const detail = await res.json().catch(() => ({}));
    throw new Error(detail.detail || "Ошибка импорта");
  }
  return res.json();
}

export async function addDevice(snapshotId, file) {
  const body = new FormData();
  body.append("file", file);
  const res = await fetch(`${API}/api/snapshots/${snapshotId}/devices`, { method: "POST", body });
  if (!res.ok) {
    const detail = await res.json().catch(() => ({}));
    throw new Error(detail.detail || "Не удалось добавить устройство");
  }
  return res.json();
}

export async function addNeighbor(snapshotId, file) {
  return addDevice(snapshotId, file);
}

export async function tracePath(snapshotId, payload) {
  const res = await fetch(`${API}/api/snapshots/${snapshotId}/trace`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  if (!res.ok) {
    const detail = await res.json().catch(() => ({}));
    throw new Error(detail.detail || "Не удалось построить путь");
  }
  return res.json();
}
