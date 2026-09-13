# TASK: Topology catalog — numbers on wires, full text off the canvas

## Why

Третья итерация чипов на линиях. Длинные `C3850-A Port-channel1 — N9K-A port-channel10` **ещё хуже** читаются: текст наезжает, `fitView` сжимает, 6 L2 + 5 GRE не помещаются на рёбрах.

Читаемость = **не писать предложение на линии**. На холсте — короткий номер. Полный текст — в списке рядом, крупно, всегда виден.

Маркетинг не нужен.

## Goal

1. **On each L2 / GRE / vPC edge:** only a **badge** `1`…`N` (14px+, kind color). No `Port-channel`, no `Tun04 ↔ Tun03` on the wire (except path hop — see below).
2. **Catalog under the map** (or right of it, still in `canvas-wrap`, not the route sidebar): grouped, 14px+ font, one row per numbered link:

   ```
   L2
   1  C3850-A Po1 — N9K-A Po10
   2  C3850-A Po1 — N9K-B Po10
   3  C3850-B Po1 — N9K-A Po11
   4  C3850-B Po1 — N9K-B Po11
   5  MTK LACP1 — N9K-A Po3
   6  MTK LACP1 — N9K-B Po3
   7  N9K-A — N9K-B  vpc peer-link

   GRE
   8  MTK Tun04 — DirectCODD Tun03
   …
   ```

   Shorten `Port-channel` / `port-channel` → `Po`. Full hostname in `title`.

3. **Interaction:** click badge or catalog row → highlight that edge (thicker stroke) + select row. Hover same.
4. **Nexthop:** still no idle number (too many). Hover stroke shows `via …` in the catalog highlight or a tooltip. Do not number all 12 vias.
5. **Path query:** numbered badges on path hops stay; those catalog rows get a yellow «путь» mark. Optional one yellow hop chip (`VLAN504`) on the path edge only — not a return of idle L2 essays.
6. Remove the old mid-edge L2/GRE text chips and the long `gre-exchange` dump if the catalog replaces it (keep unmatched GRE hint).

Layers, kinds, tracer — unchanged.

## Tests

- Catalog contains `C3850` / `N9K` / `Po` and `Tun04` (or `Tun`) as **list text**, not only `data-label`.
- Edge badges are digits (`data-edge-badge="1"`).
- Clicking a catalog row sets highlight (`data-picked` / class).
- Path still `data-directed`.
- No visible idle chip with `Port-channel` on the canvas.

## Acceptance

1. Default fitView: numbers on L2/GRE are readable; **no overlapping sentences** on wires.
2. User can read every L2 pair from the catalog without zoom.
3. pytest + vitest + security-check pass.

## Handoff

DEV.md → otladchik → testirovschik → DOCS (catalog + numbers).
