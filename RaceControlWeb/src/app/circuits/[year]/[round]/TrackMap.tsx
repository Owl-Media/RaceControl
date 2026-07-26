"use client";

import { useMemo } from "react";
import { createProjector, rotatePoints, speedColor } from "@/lib/trackGeometry";
import type { CircuitMap } from "@/lib/types";

const VB = 600;
const DRS_OPEN = new Set([10, 12, 14]);

export function TrackMap({ map }: { map: CircuitMap }) {
  const { segments, corners, start, minSpeed, maxSpeed } = useMemo(() => {
    if (map.points.length === 0) return { segments: [], corners: [], start: null, minSpeed: 0, maxSpeed: 0 };

    const rotated = rotatePoints(
      map.points.map((p) => ({ x: p.x, y: p.y })),
      map.rotation,
    );
    const projector = createProjector(rotated, VB, VB, 36);
    const screen = rotated.map((p) => projector.project(p));

    const speeds = map.points.map((p) => p.speed);
    const minSpeed = Math.min(...speeds);
    const maxSpeed = Math.max(...speeds);

    const segments = [];
    for (let i = 1; i < screen.length; i++) {
      const a = screen[i - 1];
      const b = screen[i];
      const speed = (map.points[i - 1].speed + map.points[i].speed) / 2;
      const drsOpen = DRS_OPEN.has(map.points[i - 1].drs) && DRS_OPEN.has(map.points[i].drs);
      segments.push({ a, b, color: speedColor(speed, minSpeed, maxSpeed), drsOpen });
    }

    const rotatedCorners = rotatePoints(
      map.corners.map((c) => ({ x: c.x, y: c.y })),
      map.rotation,
    );
    const corners = map.corners.map((c, i) => ({ ...c, screen: projector.project(rotatedCorners[i]) }));

    const start = screen[0] ?? null;

    return { segments, corners, start, minSpeed, maxSpeed };
  }, [map]);

  if (segments.length === 0) {
    return (
      <div className="flex h-80 items-center justify-center rounded-lg border border-dashed border-border text-sm text-muted">
        No track position data available for this race.
      </div>
    );
  }

  return (
    <div>
      <svg viewBox={`0 0 ${VB} ${VB}`} className="w-full rounded-lg border border-border bg-surface">
        {/* base track surface */}
        <polyline
          points={segments.map((s) => `${s.a.x},${s.a.y}`).concat(`${segments[segments.length - 1].b.x},${segments[segments.length - 1].b.y}`).join(" ")}
          fill="none"
          stroke="#2a2a30"
          strokeWidth={10}
          strokeLinejoin="round"
          strokeLinecap="round"
        />
        {/* speed-gradient racing line */}
        {segments.map((s, i) => (
          <line key={i} x1={s.a.x} y1={s.a.y} x2={s.b.x} y2={s.b.y} stroke={s.color} strokeWidth={5} strokeLinecap="round" />
        ))}
        {/* DRS zone overlay */}
        {segments
          .filter((s) => s.drsOpen)
          .map((s, i) => (
            <line key={`drs-${i}`} x1={s.a.x} y1={s.a.y} x2={s.b.x} y2={s.b.y} stroke="#22c55e" strokeWidth={2} strokeLinecap="round" opacity={0.9} />
          ))}
        {/* start/finish */}
        {start && <circle cx={start.x} cy={start.y} r={7} fill="#f2f2f4" stroke="#0a0a0c" strokeWidth={2} />}
        {/* corner markers */}
        {corners.map((c) => (
          <g key={c.number}>
            <circle cx={c.screen.x} cy={c.screen.y} r={9} fill="var(--surface-raised)" stroke="var(--border)" strokeWidth={1} />
            <text x={c.screen.x} y={c.screen.y + 3.5} textAnchor="middle" fontSize={9} fill="var(--muted)">
              {c.number}
              {c.letter}
            </text>
          </g>
        ))}
      </svg>
      <div className="mt-2 flex items-center justify-between text-xs text-muted">
        <span>Slow</span>
        <div className="h-1.5 flex-1 mx-2 rounded-full" style={{ background: "linear-gradient(90deg, #5b4fe8, #3b82f6, #22c55e, #eab308)" }} />
        <span>Fast</span>
      </div>
      <p className="mt-1 text-center text-xs text-muted">
        {Math.round(minSpeed)}–{Math.round(maxSpeed)} km/h · <span className="text-emerald-500">green</span> = DRS zone
      </p>
    </div>
  );
}
