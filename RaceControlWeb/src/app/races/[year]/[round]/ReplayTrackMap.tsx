"use client";

import { useEffect, useMemo, useRef } from "react";
import { createProjector, densifyTrace, rotatePoints } from "@/lib/trackGeometry";
import { LoadingState } from "@/components/StateViews";
import { REPLAY_TICK_MS } from "@/lib/replay";
import type { CircuitMap, ReplayLapPositions } from "@/lib/types";

const VB = 600;

export function ReplayTrackMap({
  circuit,
  circuitLoading = false,
  positionsLoading = false,
  lapPositions,
  driverTeamColors,
  playing,
}: {
  circuit: CircuitMap | undefined;
  /** The track outline request is still in flight — distinct from "there is
   * no outline", which is only knowable once it has finished. */
  circuitLoading?: boolean;
  /** The car-position request is still in flight; the track can already be
   * drawn, but there are no cars to place on it yet. */
  positionsLoading?: boolean;
  /** Position samples for the lap currently on screen, or undefined if unavailable. */
  lapPositions: ReplayLapPositions | undefined;
  driverTeamColors: Record<string, string | null>;
  playing: boolean;
}) {
  const { screenOutline, projector } = useMemo(() => {
    if (!circuit || circuit.outline.length === 0) return { screenOutline: [] as { x: number; y: number }[], projector: null };
    // Smooth the drawn outline the same way the circuits page does — the
    // backend's ~350 evenly-spaced points are accurate but still show
    // visible facets through tight corners without curve interpolation.
    const dense = densifyTrace(circuit.outline, 6);
    const rotated = rotatePoints(dense, circuit.rotation);
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

  // Only report missing data once the request has actually finished — while
  // it's in flight there is legitimately nothing to draw yet, and showing the
  // failure copy in the meantime reads as a hard error that then silently
  // fixes itself.
  if (circuitLoading) {
    return (
      <div className="flex h-72 items-center justify-center rounded-lg border border-border bg-surface">
        <LoadingState label="Loading track map…" />
      </div>
    );
  }

  if (!projector || screenOutline.length === 0) {
    return (
      <div className="flex h-72 items-center justify-center rounded-lg border border-dashed border-border text-sm text-muted">
        No track position data available for this race.
      </div>
    );
  }

  const start = screenOutline[0];

  return (
    <div className="relative">
      {/* The viewBox is square, so an unconstrained `w-full` makes the map as
          tall as the container is wide — over 1100px on a desktop layout,
          pushing the running order entirely below the fold. Cap the height and
          let preserveAspectRatio letterbox it instead. */}
      <svg
        viewBox={`0 0 ${VB} ${VB}`}
        preserveAspectRatio="xMidYMid meet"
        className="max-h-[45vh] w-full rounded-lg border border-border bg-surface lg:max-h-[calc(100vh-10rem)]"
      >
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

      {/* The track outline arrives well before the per-lap car positions, so
          the map can sit there looking empty. Say why rather than leaving it
          ambiguous. */}
      {positionsLoading && drivers.length === 0 && (
        <div className="absolute inset-x-0 bottom-3 flex justify-center">
          <span className="flex items-center gap-2 rounded-full border border-border bg-surface/90 px-3 py-1.5 text-xs text-muted backdrop-blur">
            <span
              role="status"
              aria-label="Loading"
              className="h-3 w-3 animate-spin rounded-full border-2 border-border border-t-racing-red"
            />
            Loading car positions…
          </span>
        </div>
      )}
    </div>
  );
}
