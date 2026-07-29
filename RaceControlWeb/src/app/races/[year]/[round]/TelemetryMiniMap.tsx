"use client";

import { useMemo } from "react";
import { useCircuitMap } from "@/lib/api";
import { createProjector, densifyTrace, nearestIndexByDistance, rotatePoints, type RawPoint } from "@/lib/trackGeometry";
import type { TelemetryTrace } from "@/lib/types";

const VB = 260;

/**
 * Track outline for the telemetry tab, with a dot per driver at the scrubbed
 * point on the lap.
 *
 * The outline deliberately comes from the circuit endpoint rather than from
 * the telemetry trace being charted. A single lap's *position* channel is
 * often degraded — it updates ~10x slower than the rest of the telemetry and
 * can carry as few as ~20 genuinely distinct samples, which draws as a
 * hard-edged polygon. Neither resampling nor curve smoothing can recover
 * shape that was never in the source. The circuit endpoint already solves
 * this (`_pick_outline_lap` picks a lap with a rich position trace, falling
 * back across laps until it finds one), which is why every other map in the
 * app looks smooth — they all draw from it. The telemetry trace is still
 * used for the dots, since those must reflect the selected lap.
 */
export function TelemetryMiniMap({
  year,
  round,
  traces,
  scrubDistance,
}: {
  year: number;
  round: number;
  traces: TelemetryTrace[];
  scrubDistance: number | null;
}) {
  const { data: circuit } = useCircuitMap(year, round);

  const longest = useMemo(
    () => (traces.length ? traces.reduce((a, b) => (a.x.length > b.x.length ? a : b)) : null),
    [traces],
  );

  // Both sources are in the same underlying coordinate space, so the dots can
  // be rotated and projected with exactly the transform derived from whichever
  // outline is in use.
  const { outline, projector, rotation } = useMemo(() => {
    const fromCircuit = circuit && circuit.outline.length > 0;
    const raw: RawPoint[] = fromCircuit
      ? circuit.outline
      : longest
        ? longest.x.map((x, i) => ({ x, y: longest.y[i] }))
        : [];
    if (raw.length === 0) return { outline: [], projector: null, rotation: 0 };

    const rot = fromCircuit ? circuit.rotation : 0;
    const dense = densifyTrace(raw, 6);
    const rotated = rotatePoints(dense, rot);
    const proj = createProjector(rotated, VB, VB);
    return { outline: rotated.map((p) => proj.project(p)), projector: proj, rotation: rot };
  }, [circuit, longest]);

  const scrubDots = useMemo(() => {
    if (scrubDistance == null || !projector) return [];
    return traces.map((t) => {
      const idx = nearestIndexByDistance(t.distance, scrubDistance);
      const [rotated] = rotatePoints([{ x: t.x[idx], y: t.y[idx] }], rotation);
      return { color: t.teamColor || "#e10600", code: t.code, point: projector.project(rotated) };
    });
  }, [traces, scrubDistance, projector, rotation]);

  if (outline.length === 0) return null;

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
