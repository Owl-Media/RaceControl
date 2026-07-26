"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { createProjector, rotatePoints } from "@/lib/trackGeometry";
import type { CircuitMap, ReplayLapPositions } from "@/lib/types";

const VB = 600;
const TICK_MS = 700; // must match the lap-advance interval in ReplayTab

export function ReplayTrackMap({
  circuit,
  lapPositions,
  driverTeamColors,
  playing,
  tickKey,
}: {
  circuit: CircuitMap | undefined;
  /** Position samples for the lap currently on screen, or undefined if unavailable. */
  lapPositions: ReplayLapPositions | undefined;
  driverTeamColors: Record<string, string | null>;
  playing: boolean;
  /** Changes every time the current lap changes, to restart the sub-lap animation. */
  tickKey: number;
}) {
  // Remounting on tickKey gives each lap's animator a fresh sampleIndex of 0
  // via useState's initializer, rather than resetting it with a setState
  // call inside an effect (which triggers an avoidable extra render).
  return (
    <ReplayTrackMapAnimator
      key={tickKey}
      circuit={circuit}
      lapPositions={lapPositions}
      driverTeamColors={driverTeamColors}
      playing={playing}
    />
  );
}

function ReplayTrackMapAnimator({
  circuit,
  lapPositions,
  driverTeamColors,
  playing,
}: {
  circuit: CircuitMap | undefined;
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

  // Smoothly step through this lap's position samples over the same window
  // the lap index advances on, so cars visibly move around the track between
  // laps rather than teleporting once per tick.
  const [sampleIndex, setSampleIndex] = useState(0);
  const frameRef = useRef<number>(0);

  useEffect(() => {
    if (!playing) return;
    const start = performance.now();

    function step(now: number) {
      const maxSamples = Math.max(
        1,
        ...Object.values(lapPositions?.positions ?? {}).map((pts) => pts.length),
      );
      const t = Math.min(1, (now - start) / TICK_MS);
      setSampleIndex(Math.min(maxSamples - 1, Math.floor(t * maxSamples)));
      if (t < 1) frameRef.current = requestAnimationFrame(step);
    }
    frameRef.current = requestAnimationFrame(step);
    return () => cancelAnimationFrame(frameRef.current);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [playing]);

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
      {lapPositions &&
        Object.entries(lapPositions.positions).map(([code, pts]) => {
          if (pts.length === 0) return null;
          const idx = Math.min(pts.length - 1, sampleIndex);
          const [x, y] = pts[idx];
          const rotated = rotatePoints([{ x, y }], circuit!.rotation)[0];
          const screen = projector.project(rotated);
          const color = driverTeamColors[code] || "#6b6b72";
          return (
            <g
              key={code}
              style={{ transition: "transform 120ms linear" }}
              transform={`translate(${screen.x}, ${screen.y})`}
            >
              <circle r={7} fill={color} stroke="#0a0a0c" strokeWidth={1.5} />
              <text y={-11} textAnchor="middle" fontSize={9} fontWeight={600} fill="var(--foreground)">
                {code}
              </text>
            </g>
          );
        })}
    </svg>
  );
}
