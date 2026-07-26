"use client";

import { useMemo } from "react";
import { createProjector, nearestIndexByDistance, type RawPoint } from "@/lib/trackGeometry";
import type { TelemetryTrace } from "@/lib/types";

const VB = 260;

export function TelemetryMiniMap({ traces, scrubDistance }: { traces: TelemetryTrace[]; scrubDistance: number | null }) {
  const longest = useMemo(
    () => (traces.length ? traces.reduce((a, b) => (a.x.length > b.x.length ? a : b)) : null),
    [traces],
  );

  const projector = useMemo(() => {
    if (!longest) return null;
    const raw: RawPoint[] = longest.x.map((x, i) => ({ x, y: longest.y[i] }));
    return createProjector(raw, VB, VB);
  }, [longest]);

  const outline = useMemo(() => {
    if (!longest || !projector) return [];
    return longest.x.map((x, i) => projector.project({ x, y: longest.y[i] }));
  }, [longest, projector]);

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
