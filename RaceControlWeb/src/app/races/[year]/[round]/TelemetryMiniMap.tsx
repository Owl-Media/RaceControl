"use client";

import { useMemo } from "react";
import { createProjector, densifyTrace, nearestIndexByDistance, type RawPoint } from "@/lib/trackGeometry";
import type { TelemetryTrace } from "@/lib/types";

const VB = 260;

export function TelemetryMiniMap({ traces, scrubDistance }: { traces: TelemetryTrace[]; scrubDistance: number | null }) {
  const longest = useMemo(
    () => (traces.length ? traces.reduce((a, b) => (a.x.length > b.x.length ? a : b)) : null),
    [traces],
  );

  // Smooth the drawn outline with the same Catmull-Rom pass every other track
  // map uses (TrackMap / MiniTrackMap / ReplayTrackMap). Without it this map
  // renders the position samples as raw straight segments, which reads as a
  // hard-edged polygon through corners — the position channel updates far
  // less often than the rest of the telemetry feed, so consecutive samples
  // can be a long way apart on track.
  const dense = useMemo<RawPoint[]>(() => {
    if (!longest) return [];
    const raw: RawPoint[] = longest.x.map((x, i) => ({ x, y: longest.y[i] }));
    return densifyTrace(raw, 6);
  }, [longest]);

  // Built from the smoothed outline, then reused for the scrub dots so both
  // stay on one consistent transform.
  const projector = useMemo(() => (dense.length ? createProjector(dense, VB, VB) : null), [dense]);

  const outline = useMemo(() => {
    if (!projector) return [];
    return dense.map((p) => projector.project(p));
  }, [dense, projector]);

  const scrubDots = useMemo(() => {
    if (scrubDistance == null || !projector) return [];
    return traces.map((t) => {
      const idx = nearestIndexByDistance(t.distance, scrubDistance);
      return { color: t.teamColor || "#e10600", code: t.code, point: projector.project({ x: t.x[idx], y: t.y[idx] }) };
    });
  }, [traces, scrubDistance, projector]);

  if (!longest) return null;

  return (
    <svg viewBox={`0 0 ${VB} ${VB}`} className="h-full w-full">
      <polyline
        points={outline.map((p) => `${p.x},${p.y}`).join(" ")}
        fill="none"
        stroke="#4b4b52"
        strokeWidth={4}
        strokeLinejoin="round"
        strokeLinecap="round"
      />
      {scrubDots.map((d, i) => (
        <circle key={i} cx={d.point.x} cy={d.point.y} r={6} fill={d.color} stroke="#0a0a0c" strokeWidth={2} />
      ))}
    </svg>
  );
}
