"use client";

import { useEffect, useMemo, useRef } from "react";
import { createProjector, rotatePoints } from "@/lib/trackGeometry";
import { REPLAY_TICK_MS } from "@/lib/replay";
import type { CircuitMap, ReplayLapPositions } from "@/lib/types";

const VB = 600;

export function ReplayTrackMap({
  circuit,
  lapPositions,
  driverTeamColors,
  playing,
}: {
  circuit: CircuitMap | undefined;
  /** Position samples for the lap currently on screen, or undefined if unavailable. */
  lapPositions: ReplayLapPositions | undefined;
  driverTeamColors: Record<string, string | null>;
  playing: boolean;
}) {
  const { screenOutline, projector } = useMemo(() => {
    if (!circuit || circuit.outline.length === 0) return { screenOutline: [] as { x: number; y: number }[], projector: null };
    const rotated = rotatePoints(circuit.outline, circuit.rotation);
    const proj = createProjector(rotated, VB, VB, 36);
    return { screenOutline: rotated.map((p) => proj.project(p)), projector: proj };
  }, [circuit]);

  const rotation = circuit?.rotation ?? 0;
  const drivers = lapPositions ? Object.keys(lapPositions.positions) : [];

  // Cars are animated imperatively (direct DOM writes via refs), not through
  // React state, so a ~60fps loop never triggers a React re-render — this
  // both keeps it smooth and avoids state-update ordering issues around
  // pause/resume and lap changes.
  const dotRefs = useRef<Record<string, SVGGElement | null>>({});
  const frameRef = useRef<number>(0);

  useEffect(() => {
    const start = performance.now();

    function place(fraction: number) {
      if (!projector || !lapPositions) return;
      for (const [code, pts] of Object.entries(lapPositions.positions)) {
        const el = dotRefs.current[code];
        if (!el || pts.length === 0) continue;
        const idx = Math.min(pts.length - 1, Math.floor(fraction * pts.length));
        const point = pts[idx];
        if (!point) continue;
        const [x, y] = point;
        if (!Number.isFinite(x) || !Number.isFinite(y)) continue;
        const [rotated] = rotatePoints([{ x, y }], rotation);
        const screen = projector.project(rotated);
        el.setAttribute("transform", `translate(${screen.x}, ${screen.y})`);
      }
    }

    // Always place the first sample immediately (covers the paused case, and
    // avoids a blank frame right as a new lap starts while playing).
    place(0);

    if (!playing) return;

    function step(now: number) {
      const t = Math.min(1, (now - start) / REPLAY_TICK_MS);
      place(t);
      if (t < 1) frameRef.current = requestAnimationFrame(step);
    }
    frameRef.current = requestAnimationFrame(step);
    return () => cancelAnimationFrame(frameRef.current);
  }, [playing, lapPositions, projector, rotation]);

  if (!projector || screenOutline.length === 0) {
    return (
      <div className="flex h-72 items-center justify-center rounded-lg border border-dashed border-border text-sm text-muted">
        No track position data available for this race.
      </div>
    );
  }

  const start = screenOutline[0];

  return (
    <svg viewBox={`0 0 ${VB} ${VB}`} className="w-full rounded-lg border border-border bg-surface">
      <polyline
        points={screenOutline.map((p) => `${p.x},${p.y}`).join(" ")}
        fill="none"
        stroke="#2a2a30"
        strokeWidth={10}
        strokeLinejoin="round"
        strokeLinecap="round"
      />
      {start && <circle cx={start.x} cy={start.y} r={6} fill="#f2f2f4" stroke="#0a0a0c" strokeWidth={2} />}
      {drivers.map((code) => (
        <g
          key={code}
          ref={(el) => {
            dotRefs.current[code] = el;
          }}
        >
          <circle r={7} fill={driverTeamColors[code] || "#6b6b72"} stroke="#0a0a0c" strokeWidth={1.5} />
          <text y={-11} textAnchor="middle" fontSize={9} fontWeight={600} fill="var(--foreground)">
            {code}
          </text>
        </g>
      ))}
    </svg>
  );
}
