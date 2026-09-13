# DEV: Topology catalog — numbers on wires

Idle L2/GRE sentences are off the canvas. Each LACP / vPC / GRE edge keeps a **kind-colored digit badge** (≥14px). The full line lives in a **catalog under the map** (still in `canvas-wrap`). Nexthop stays unnumbered; `via …` is hover/tooltip only.

## Numbering order

1-based, **one sequence** across groups. Nexthop is skipped.

1. **LACP** first  
2. **vPC** next  
3. **GRE** last  

Inside LACP/GRE, sort by catalog ends: left device (`C3850` → `MTK` → `N9K` → other), left iface, right device, right iface. vPC is alphabetical `N9K-A` then `N9K-B`. `Port-channel` / `port-channel` → `Po`.

Live roster (8 devices):

| # | Group | Line |
|---|---|---|
| 1–4 | L2 | C3850-A/B Po1 — N9K-A/B Po10/Po11 |
| 5–6 | L2 | MTK LACP1 — N9K-A/B Po3 |
| 7 | L2 | `N9K-A — N9K-B  vpc peer-link` |
| 8–12 | GRE | MTK / CAFAP / DirectCODD Tun pairs |

## Canvas / catalog / path

- Badge on the wire is only `1`…`N`. No `Port-channel`, no `Tun04 ↔ Tun03` on idle edges.
- Catalog: **L2** column then **GRE**, 14px+. Click/hover row or badge thickens that stroke (`data-picked`).
- Path: `data-directed` arrows stay. Catalog rows on the path get a yellow **путь** mark. Optional yellow hop chip is **iface only** (`VLAN504`), not the old L2 essay.
- Old `gre-exchange` prefix dump is gone. Unmatched GRE hint remains.

## Files touched

- `frontend/src/components/SiteMap.jsx` — badges, catalog, `catalogLine` / `catalogSortKey`
- `frontend/src/components/TopoEdge.jsx` — digit badge; hop chip only on path / nexthop hover
- `frontend/src/index.css` — badge + catalog; removed `.gre-exchange`
- `frontend/src/App.test.jsx` — catalog text, digit badges, click highlight, directed path, no idle Port-channel chip
- `docs/handoff/DEV.md`

## How to try (default zoom)

Terminal 1 — API on 8000 (no `--reload`):

```
cd c:\Users\tankov\coding\nettrack
set DATABASE_URL=sqlite:///c:/Users/tankov/coding/nettrack/nettrack.db
set SKIP_SEED=0
.\.venv\Scripts\python.exe -m uvicorn app.main:app --app-dir backend --host 127.0.0.1 --port 8000
```

PowerShell: `$env:DATABASE_URL="sqlite:///c:/Users/tankov/coding/nettrack/nettrack.db"`

Terminal 2 — UI:

```
cd c:\Users\tankov\coding\nettrack\frontend
npm run dev
```

Open **http://localhost:5173**. Leave default `fitView`. Wires should show small cyan/gold/violet numbers; read `C3850-A Po1 — N9K-A Po10` from the list under the map. Hover a muted L3 dash for `via …`.

**Эмуляция клиента** → `WS-C3850-A` → VLAN504 → `8.8.8.8` → **Показать путь**. Directed arrows stay; that L2 catalog row is marked **путь**; yellow chip is `VLAN504` only.

Tests (not the full security gate):

```
cd c:\Users\tankov\coding\nettrack\frontend
npm test
```

## Open questions

- GRE advertised/received prefixes are no longer listed under the map. Restore as a catalog expand if otladchik wants them back.
- Path hop chip is `VLAN504` (iface), not `VLAN504 → 10.0.32.190`.
