# TEST_REPORT

Status: **OK**

REVIEW.md was **APPROVED**. Gate used project `.venv` only. No product code was changed. No commit.

Covered TASK: catalog list with **Po** / **Tun**, digit badges on wires, **no `Port-channel` on idle canvas**.

## Unit / Integration

Command (cwd `backend/`):

```
C:\Users\tankov\coding\nettrack\.venv\Scripts\python.exe -m pytest tests -q
```

Result: **30 passed**, 1 warning (Starlette `anyio.abc.BlockingPortal` deprecation in `.venv`), 1.74s. Exit 0.

Running `python -m pytest` from `backend/` with a relative `.\.venv` fails: venv lives at the **repo root**. Use the root interpreter as above.

| File | What ran |
|---|---|
| `test_parser.py` | sample `.rsc` parse, secret redaction, PPPoE default, optional CCR export |
| `test_direction.py` | WAN / LAN / VPN zones; egress / tunnel / policy / NAT |
| `test_graph.py` | PPP/VLAN/GRE/LACP nodes, namespaced ids, small box does not invent CCR jacks |
| `test_cisco.py` | NX-OS + IOS-XE fixtures, `redact_cisco`, switch schematic groups access VLAN |
| `test_site.py` | independent graphs, GRE exchange, unmatched Tun, LACP/vPC/SVI/nexthop mesh, `build_topo_links` |
| `test_trace.py` | VLAN504 → `8.8.8.8` (C3850-A L2 → N9K-A → MTK PPP egress); VLAN504 → `10.38.0.40` (Tun04 → DirectCODD deliver) |
| `test_api.py` | import + graph, health, reject unknown, add Cisco keeps MikroTik, no fixture secrets in graph blob, `POST .../trace` |

Backend inference / tracer were not part of this TASK. Mesh kinds and traces still pass as regression.

## Frontend tests

Command (cwd `frontend/`):

```
npm test
```

(`vitest run`) Result: **1 file, 16 passed**, 6.71s. Exit 0.

TASK-facing case `catalog lists L2 and GRE; badges are digits; click highlights; no idle Port-channel chip` in `frontend/src/App.test.jsx`:

- **Catalog = list text with Po / Tun.** `[data-link-catalog]` matches `/C3850/`, `/N9K/`, `/Po/`, `/Tun/`, and exact `C3850-A Po1 — N9K-A Po10`. Catalog has **no** `/Port-channel/i`. L2 rows start at `data-catalog-row="1"`; first GRE row number is `l2rows.length + 1`.
- **Badges are digits.** `[data-edge-badge]` count ≥ 4; every badge attribute and text is `/^\d+$/`. Nexthop `data-badge` is empty.
- **Idle canvas has no Port-channel chip.** `[data-edge-label]` idle chips length 0; none match `/Port-channel/i`.
- **Click highlight.** Clicking the `C3850-A Po1 — N9K-A Po10` row sets `data-picked="1"` on the row and a matching `[data-map-edge]`.

Path case `path hop chip stays visible on directed edges`:

- Two `data-directed="1"` hops; hop chip matches `VLAN504`; **no** `/Port-channel/i` on chips; catalog row `data-on-path="1"` and catalog text `/путь/`.
- `path hops mark directed edges` / `second path replaces first arrows`: WAN `dev-3->dev-1`, `dev-1->dev-0`; GRE rerender directs `dev-0->dev-5` only.

Playwright is not in `frontend/package.json`; no e2e suite.

## Security (SAST / deps)

Command (project root, project venv):

```
C:\Users\tankov\coding\nettrack\.venv\Scripts\python.exe scripts\security-check.py
```

Result: **OK: security-check passed**

`scripts/security-check.sh` wraps the same Python. Ran `.py` on Windows. Checker skips `backend/tests/fixtures/`. Did not run bandit / `npm audit` (project script exists).

## Live canvas (default fitView)

Vite `http://localhost:5173/` + API on 8000, no extra zoom (`fitView` scale ≈ **0.85**, chips in `.react-flow`).

Idle RF badges (`.react-flow [data-edge-badge]`, 12 unique, 14px, kind-colored): **1–12** digits only. Zero `.react-flow [data-edge-label]` / `.topo-edge-chip` while idle. `.react-flow` innerText has **no** `Port-channel`. Nexthop `data-badge` stays empty.

Catalog under the map (`[data-link-catalog]`, row font **14px**):

| # | Group | Line |
|---|---|---|
| 1–4 | L2 | `C3850-A Po1 — N9K-A Po10`, `C3850-A Po1 — N9K-B Po10`, `C3850-B Po1 — N9K-A Po11`, `C3850-B Po1 — N9K-B Po11` |
| 5–6 | L2 | `MTK LACP1 — N9K-A Po3`, `MTK LACP1 — N9K-B Po3` |
| 7 | L2 | `N9K-A — N9K-B vpc peer-link` |
| 8–12 | GRE | `MTK Tun01 — CAFAP-R1 Tun02`, `MTK Tun02 — CAFAP-R2 Tun03`, `MTK Tun04 — DirectCODD Tun03`, `CAFAP-R1 Tun03 — DirectCODD Tun01`, `CAFAP-R2 Tun01 — DirectCODD Tun02` |

Catalog contains `C3850`, `N9K`, `Po`, `Tun04`. Catalog has **no** `Port-channel`. Click row 1 → `data-picked="1"` on that row and LACP `dev-6`↔`dev-4` (`data-badge="1"`).

**Показать путь** WS-C3850-A / VLAN504 / `8.8.8.8`: yellow hop chip **`VLAN504` only** (not Port-channel); `data-directed` `dev-6→dev-4` (lacp badge 1) and `dev-4→dev-0` (nexthop); catalog row 1 marked **путь**. Badges stay digits 1–12. Still no `Port-channel` on the canvas.

## Coverage vs TASK.md acceptance

| # | Acceptance | Gate evidence |
|---|---|---|
| 1 | Idle wires = digits only; no Port-channel / Tun pair on idle chips | Vitest idle `[data-edge-label]` empty; live RF chips empty; 12 digit badges 14px cyan/gold/violet. |
| 2 | Catalog = full L2/GRE with `Po` / `Tun` | Vitest exact `C3850-A Po1 — N9K-A Po10` plus `/Tun/`; live 7 L2 + 5 GRE lines including `Tun04`. |
| 3 | Click catalog row highlights | Vitest + live `data-picked="1"` on row and edge. |
| 4 | Path `data-directed`; hop chip iface only; путь on catalog | Vitest VLAN504 + путь; live `VLAN504` chip and row 1 путь. |
| 5 | pytest + frontend + `scripts/security-check.py` | All three **pass**. |

## Notes

- Access-gap badges **2** and **3** sit close at default 0.85 zoom (digits, not sentences). TASK asked to kill overlapping *sentences*; residual overlap of two numbers is not a fail.
- Clipped `.map-edge-chips` / `.map-edge-audit` remain DOM doubles (24 badge nodes vs 12 in `.react-flow`). Vitest reads both; live check used `.react-flow`.
- Catalog sits under a fixed 720px `.site-map`; short viewports scroll. `путь` mark is 11px uppercase. GRE advertised/received prefixes are not in the catalog. REVIEW residuals, not failures.
- One Starlette deprecation warning; not a failure.
