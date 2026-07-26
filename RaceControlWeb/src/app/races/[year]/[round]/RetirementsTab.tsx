"use client";

import { useRetirements } from "@/lib/api";
import { LoadingState, ErrorState, EmptyState, TeamColorDot } from "@/components/StateViews";

export function RetirementsTab({ year, round }: { year: number; round: number }) {
  const { data, error, isLoading } = useRetirements(year, round);

  if (isLoading) return <LoadingState label="Loading retirements…" />;
  if (error) return <ErrorState message="Retirement data isn't available for this race." />;
  if (!data || data.retirements.length === 0) return <EmptyState message="No retirements — everyone finished." />;

  return (
    <ul className="flex flex-col gap-2">
      {data.retirements.map((r, i) => (
        <li key={i} className="flex items-center gap-3 rounded-lg border border-border bg-surface px-4 py-3">
          <TeamColorDot color={r.teamColor} />
          <div className="min-w-0 flex-1">
            <p className="truncate font-medium">{r.fullName ?? r.driver}</p>
            <p className="truncate text-sm text-muted">{r.teamName ?? "—"}</p>
          </div>
          <span className="shrink-0 rounded-full bg-racing-red/15 px-2.5 py-1 text-xs font-semibold text-racing-red">{r.status}</span>
        </li>
      ))}
    </ul>
  );
}
