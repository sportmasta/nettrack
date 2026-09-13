# REVIEW

Status: **APPROVED**

Reviewed `docs/handoff/TASK.md` and `docs/handoff/DEV.md` against `frontend/src/components/SiteMap.jsx`, `frontend/src/components/TopoEdge.jsx`, `frontend/src/index.css`, `frontend/src/App.test.jsx`. Backend inference was not part of this change.

Idle L2/GRE sentences are off the wires. Each LACP / vPC / GRE edge shows a **kind-colored digit badge** (14px). Full text lives in a **catalog under the map** inside `canvas-wrap` (not the route sidebar). Nexthop stays unnumbered; `via …` is hover chip / tooltip only.

## Acceptance

1. **Idle wires = digits only.** `edgeChipText` returns empty for idle LACP/vPC/GRE. `TopoEdge` draws `data-edge-badge` as the number. No `Port-channel`, no `Tun04 ↔ Tun03` on idle chips.

2. **Catalog = full L2/GRE with `Po`.** `catalogLine` + `shortIface` (`Port-channel` / `port-channel` → `Po`). L2 then GRE, one 1-based sequence. Example: `C3850-A Po1 — N9K-A Po10`. Font 14px+. Unmatched GRE hint remains; `.gre-exchange` is gone.

3. **Click / hover highlight.** Catalog row or badge sets `picked` / `hotId`. Row gets `data-picked="1"`; matching edge thickens.

4. **Nexthop not numbered.** Hover still shows `via …`.

5. **Path directed.** Catalog rows on the path get yellow **путь**. Hop chip is iface only (`VLAN504`).

## Residual (not blocking)

- Catalog sits under a fixed 720px `.site-map`; short viewports scroll.
- GRE advertised/received prefixes are not in the catalog.
- `.map-edge-chips` / `.map-edge-audit` remain clipped DOM doubles for vitest.
- `showIdleNh` remains a dead `false` flag.
