// Ports the projection math from RaceControlApp/RaceControl/Features/Circuits/TrackMapRich.swift:
// rotate raw car-position telemetry by the circuit's rotation, then autoscale/center it
// into an SVG viewBox. Shared by the circuit track map and the telemetry mini-map.

export interface RawPoint {
  x: number;
  y: number;
}

export interface ScreenPoint {
  x: number;
  y: number;
}

export function rotatePoints(points: RawPoint[], rotationDegrees: number): RawPoint[] {
  const theta = (rotationDegrees * Math.PI) / 180;
  const cos = Math.cos(theta);
  const sin = Math.sin(theta);
  return points.map((p) => ({
    x: p.x * cos - p.y * sin,
    y: p.x * sin + p.y * cos,
  }));
}

export interface Projector {
  project(point: RawPoint): ScreenPoint;
}

/**
 * Derive a projection (from a reference set of track-space points) that fits an SVG
 * viewBox of the given size, preserving aspect ratio, centered, with padding. Y is
 * flipped (screen y grows downward). Reuse the same Projector for every point drawn
 * on top of the same map so they stay aligned to one consistent transform.
 */
export function createProjector(
  referencePoints: RawPoint[],
  viewBoxWidth: number,
  viewBoxHeight: number,
  padding = 24,
): Projector {
  if (referencePoints.length === 0) {
    return { project: (p) => p };
  }
  const xs = referencePoints.map((p) => p.x);
  const ys = referencePoints.map((p) => p.y);
  const minX = Math.min(...xs);
  const maxX = Math.max(...xs);
  const minY = Math.min(...ys);
  const maxY = Math.max(...ys);
  const spanX = maxX - minX || 1;
  const spanY = maxY - minY || 1;
  const availW = viewBoxWidth - padding * 2;
  const availH = viewBoxHeight - padding * 2;
  const scale = Math.min(availW / spanX, availH / spanY);
  const centerX = (minX + maxX) / 2;
  const centerY = (minY + maxY) / 2;
  return {
    project: (p) => ({
      x: viewBoxWidth / 2 + (p.x - centerX) * scale,
      y: viewBoxHeight / 2 - (p.y - centerY) * scale,
    }),
  };
}

/** Convenience one-shot: project every point in a set against its own bounds. */
export function projectToViewBox(
  points: RawPoint[],
  viewBoxWidth: number,
  viewBoxHeight: number,
  padding = 24,
): ScreenPoint[] {
  const projector = createProjector(points, viewBoxWidth, viewBoxHeight, padding);
  return points.map((p) => projector.project(p));
}

/** 4-stop speed gradient (slow -> fast): indigo, blue, green, yellow. */
export function speedColor(speed: number, minSpeed: number, maxSpeed: number): string {
  const stops: [number, string][] = [
    [0, "#5b4fe8"],
    [0.4, "#3b82f6"],
    [0.7, "#22c55e"],
    [1, "#eab308"],
  ];
  const span = maxSpeed - minSpeed || 1;
  const t = Math.min(1, Math.max(0, (speed - minSpeed) / span));
  for (let i = 1; i < stops.length; i++) {
    const [t0, c0] = stops[i - 1];
    const [t1, c1] = stops[i];
    if (t <= t1) {
      const localT = (t - t0) / (t1 - t0 || 1);
      return lerpColor(c0, c1, localT);
    }
  }
  return stops[stops.length - 1][1];
}

function lerpColor(a: string, b: string, t: number): string {
  const pa = hexToRgb(a);
  const pb = hexToRgb(b);
  const r = Math.round(pa.r + (pb.r - pa.r) * t);
  const g = Math.round(pa.g + (pb.g - pa.g) * t);
  const bch = Math.round(pa.b + (pb.b - pa.b) * t);
  return `rgb(${r}, ${g}, ${bch})`;
}

function hexToRgb(hex: string): { r: number; g: number; b: number } {
  const clean = hex.replace("#", "");
  return {
    r: parseInt(clean.slice(0, 2), 16),
    g: parseInt(clean.slice(2, 4), 16),
    b: parseInt(clean.slice(4, 6), 16),
  };
}

/** Nearest-index lookup by cumulative distance, for scrubbing telemetry traces. */
export function nearestIndexByDistance(distances: number[], target: number): number {
  let lo = 0;
  let hi = distances.length - 1;
  while (lo < hi) {
    const mid = (lo + hi) >> 1;
    if (distances[mid] < target) lo = mid + 1;
    else hi = mid;
  }
  return lo;
}
