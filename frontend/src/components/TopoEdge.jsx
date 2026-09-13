import { useMemo } from "react";
import { BaseEdge, EdgeLabelRenderer, getBezierPath } from "@xyflow/react";

export function edgeChipText(data, hot = false) {
  if (!data) return "";
  if (data.onPath) return data.hopText || "";
  if (data.kind === "nexthop") return hot || data.showIdleNh ? data.idleText || "" : "";
  return "";
}

function shiftEnds(sourceX, sourceY, targetX, targetY, bend) {
  const dx = targetX - sourceX;
  const dy = targetY - sourceY;
  const len = Math.hypot(dx, dy) || 1;
  const ox = (-dy / len) * bend;
  const oy = (dx / len) * bend;
  return {
    sourceX: sourceX + ox,
    sourceY: sourceY + oy,
    targetX: targetX + ox,
    targetY: targetY + oy,
    midX: (sourceX + targetX) / 2 + ox,
    midY: (sourceY + targetY) / 2 + oy,
  };
}

function collapsePts(pts) {
  const out = [];
  for (const p of pts) {
    const last = out[out.length - 1];
    if (last && Math.abs(last.x - p.x) < 0.6 && Math.abs(last.y - p.y) < 0.6) continue;
    out.push(p);
  }
  return out;
}

function roundedPath(pts, r = 12) {
  if (pts.length < 2) return "";
  if (pts.length === 2) return `M ${pts[0].x} ${pts[0].y} L ${pts[1].x} ${pts[1].y}`;
  let d = `M ${pts[0].x} ${pts[0].y}`;
  for (let i = 1; i < pts.length - 1; i += 1) {
    const p0 = pts[i - 1];
    const p1 = pts[i];
    const p2 = pts[i + 1];
    const dx1 = p1.x - p0.x;
    const dy1 = p1.y - p0.y;
    const dx2 = p2.x - p1.x;
    const dy2 = p2.y - p1.y;
    const l1 = Math.hypot(dx1, dy1) || 1;
    const l2 = Math.hypot(dx2, dy2) || 1;
    const rr = Math.min(r, l1 / 2, l2 / 2);
    d += ` L ${p1.x - (dx1 / l1) * rr} ${p1.y - (dy1 / l1) * rr}`;
    d += ` Q ${p1.x} ${p1.y} ${p1.x + (dx2 / l2) * rr} ${p1.y + (dy2 / l2) * rr}`;
  }
  const last = pts[pts.length - 1];
  d += ` L ${last.x} ${last.y}`;
  return d;
}

function pointAlong(pts, t) {
  const segs = [];
  let total = 0;
  for (let i = 1; i < pts.length; i += 1) {
    const len = Math.hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y);
    segs.push({ a: pts[i - 1], b: pts[i], len });
    total += len;
  }
  if (!segs.length || total < 1) return pts[0] || { x: 0, y: 0 };
  let walk = Math.max(0, Math.min(1, t)) * total;
  for (let i = 0; i < segs.length; i += 1) {
    const s = segs[i];
    if (walk <= s.len || i === segs.length - 1) {
      const u = s.len ? Math.min(walk / s.len, 1) : 0;
      return { x: s.a.x + (s.b.x - s.a.x) * u, y: s.a.y + (s.b.y - s.a.y) * u };
    }
    walk -= s.len;
  }
  return segs[segs.length - 1].b;
}

function l2Manhattan(sx, sy, tx, ty, route) {
  const chipT = route?.chipT ?? 0.28;
  const stem = route?.stem ?? 0;
  const elbow = route?.elbow ?? 0.32;
  const nudgeX = route?.nudgeX ?? 0;
  const fromLower = sy >= ty;
  const ax = fromLower ? sx : tx;
  const ay = fromLower ? sy : ty;
  const bx = fromLower ? tx : sx;
  const by = fromLower ? ty : sy;
  const dx = bx - ax;
  const dy = by - ay;
  const flat = Math.abs(dy) < 48;
  const sameCol = Math.abs(dx) < 90;
  const dir = Math.sign(dx) || (nudgeX >= 0 ? 1 : -1);

  let pts;
  if (flat) {
    pts = [
      { x: ax, y: ay },
      { x: bx, y: by },
    ];
  } else if (sameCol) {
    const x = ax + stem;
    pts = [
      { x: ax, y: ay },
      { x, y: ay },
      { x, y: by },
      { x: bx, y: by },
    ];
  } else {
    const stemX = ax + dir * (72 + Math.abs(stem));
    const elbowY = ay + dy * elbow;
    pts = [
      { x: ax, y: ay },
      { x: stemX, y: ay },
      { x: stemX, y: elbowY },
      { x: bx, y: elbowY },
      { x: bx, y: by },
    ];
  }
  const zhopa = collapsePts(pts);
  const draw = fromLower ? zhopa : [...zhopa].reverse();
  const at = pointAlong(zhopa, chipT);
  return [roundedPath(draw, 12), at.x + nudgeX, at.y];
}

export default function TopoEdge({
  id,
  sourceX,
  sourceY,
  targetX,
  targetY,
  sourcePosition,
  targetPosition,
  style,
  markerEnd,
  data,
}) {
  const bend = data?.bend || 0;
  const kind = data?.kind || "nexthop";
  const l2 = data?.l2;
  const [edgePath, labelX, labelY] = useMemo(() => {
    if (kind === "lacp" || kind === "vpc") {
      return l2Manhattan(sourceX, sourceY, targetX, targetY, l2);
    }
    const putin = shiftEnds(sourceX, sourceY, targetX, targetY, bend);
    const curvature = 0.2 + Math.min(Math.abs(bend) / 90, 0.32) + (bend > 0 ? 0.08 : 0);
    return getBezierPath({
      sourceX: putin.sourceX,
      sourceY: putin.sourceY,
      targetX: putin.targetX,
      targetY: putin.targetY,
      sourcePosition,
      targetPosition,
      curvature,
    });
  }, [sourceX, sourceY, targetX, targetY, sourcePosition, targetPosition, bend, kind, l2]);

  const onPath = Boolean(data?.onPath);
  const hot = Boolean(data?.hot);
  const picked = Boolean(data?.picked);
  const chip = edgeChipText(data, hot);
  const badge = data?.badge;
  const title = data?.tooltip || data?.idleText || "";
  const lit = hot || picked;

  return (
    <>
      <BaseEdge id={id} path={edgePath} markerEnd={markerEnd} style={style} interactionWidth={22} />
      {badge || chip ? (
        <EdgeLabelRenderer>
          {badge ? (
            <button
              type="button"
              className={`topo-edge-badge kind-${kind}${onPath ? " is-path" : ""}${lit ? " is-picked" : ""}${data?.dim ? " is-dim" : ""} nodrag nopan`}
              data-edge-badge={String(badge)}
              data-kind={kind}
              title={title}
              style={{ transform: `translate(-50%, -50%) translate(${labelX}px, ${labelY}px)` }}
              onClick={(ev) => {
                ev.stopPropagation();
                data.onPick?.();
              }}
              onMouseEnter={() => data.onHover?.(true)}
              onMouseLeave={() => data.onHover?.(false)}
            >
              {badge}
            </button>
          ) : null}
          {chip ? (
            <div
              className={`topo-edge-chip kind-${kind}${onPath ? " is-path" : ""}${data?.dim ? " is-dim" : ""} nodrag nopan`}
              data-edge-label={chip}
              data-kind={kind}
              title={title}
              style={{
                transform: `translate(-50%, -50%) translate(${labelX}px, ${labelY + (badge ? 20 : 0)}px)`,
              }}
            >
              {chip}
            </div>
          ) : null}
        </EdgeLabelRenderer>
      ) : null}
    </>
  );
}
