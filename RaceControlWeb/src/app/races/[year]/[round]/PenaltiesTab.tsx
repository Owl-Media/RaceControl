"use client";

import { usePenalties } from "@/lib/api";
import { LoadingState, ErrorState, EmptyState, TeamColorDot } from "@/components/StateViews";
import { TeamLogo } from "@/components/TeamLogo";
import { formatClock } from "@/lib/format";
import type { Penalty, PenaltyType } from "@/lib/types";

const TYPE_COLORS: Record<PenaltyType, string> = {
  "Time Penalty": "#f0d000",
  "Stop & Go Penalty": "#ff8c1a",
  "Drive Through Penalty": "#ff8c1a",
  "Grid Penalty": "#3b82f6",
  Reprimand: "#9ca3af",
  Disqualification: "#e10600",
};

function typeColor(type: PenaltyType): string {
  return TYPE_COLORS[type] ?? "#9ca3af";
}

export function PenaltiesTab({ year, round }: { year: number; round: number }) {
  const { data, error, isLoading } = usePenalties(year, round);

  if (isLoading) return <LoadingState label="Loading penalties…" />;
  if (error) return <ErrorState message="Penalty data isn't available for this race." />;
  if (!data) return null;
  if (data.penalties.length === 0) {
    return <EmptyState message="No penalties were issued in this session." />;
  }

  return (
    <ul className="flex flex-col gap-2">
      {data.penalties.map((p, i) => (
        <PenaltyRow key={i} penalty={p} />
      ))}
    </ul>
  );
}

function PenaltyRow({ penalty: p }: { penalty: Penalty }) {
  const color = typeColor(p.type);

  return (
    <li className="flex items-start gap-3 rounded-lg border border-border bg-surface px-4 py-3">
      <span className="mt-1 h-2.5 w-2.5 shrink-0 rounded-full" style={{ backgroundColor: color }} aria-hidden />
      <div className="min-w-0 flex-1">
        <div className="flex flex-wrap items-center gap-2">
          <span
            className="tabular shrink-0 rounded-full px-2.5 py-0.5 text-xs font-semibold"
            style={{ backgroundColor: `${color}26`, color }}
          >
            {p.value ? `${p.type} (${p.value})` : p.type}
          </span>
          {p.driverCode && (
            <span className="flex shrink-0 items-center gap-1.5 rounded-full bg-border px-2 py-0.5 text-xs font-semibold text-foreground">
              <TeamColorDot color={p.teamColor} />
              <TeamLogo src={p.teamLogoUrl} name={p.teamName} sizeClassName="h-3.5 w-3.5" />
              {p.driverName ?? p.driverCode}
            </span>
          )}
          <span className="tabular shrink-0 text-xs text-muted">{formatClock(p.time)}</span>
          <span className="shrink-0 text-xs text-muted">{p.lap != null ? `Lap ${p.lap}` : "—"}</span>
        </div>
        <p className="mt-1 text-sm text-foreground">{p.reason ?? p.message ?? "—"}</p>
      </div>
    </li>
  );
}
