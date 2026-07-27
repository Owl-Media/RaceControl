"use client";

import { useReliability } from "@/lib/api";
import { LoadingState, ErrorState, EmptyState } from "@/components/StateViews";
import { TeamLogo } from "@/components/TeamLogo";
import type { ReliabilityEntry } from "@/lib/types";

function ReliabilityTable({
  title,
  rows,
  nameKey,
  showLogo = false,
}: {
  title: string;
  rows: ReliabilityEntry[];
  nameKey: "name" | "teamName";
  showLogo?: boolean;
}) {
  return (
    <div className="overflow-hidden rounded-lg border border-border">
      <div className="bg-surface px-3 py-2 text-xs font-semibold uppercase tracking-wide text-muted">{title}</div>
      <table className="w-full text-sm">
        <thead className="bg-surface/60 text-left text-xs uppercase tracking-wide text-muted">
          <tr>
            <th className="px-3 py-2 font-medium">Name</th>
            <th className="tabular px-3 py-2 text-right font-medium">Starts</th>
            <th className="tabular px-3 py-2 text-right font-medium">Finished</th>
            <th className="tabular px-3 py-2 text-right font-medium">Mech.</th>
            <th className="tabular px-3 py-2 text-right font-medium">Accident</th>
            <th className="tabular px-3 py-2 text-right font-medium">DNF</th>
            <th className="tabular px-3 py-2 text-right font-medium">Finish %</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-border">
          {rows.map((r, i) => (
            <tr key={i} className="hover:bg-surface/60">
              <td className="px-3 py-2 font-medium">
                {showLogo ? (
                  <span className="inline-flex items-center gap-2">
                    <TeamLogo src={r.teamLogoUrl} name={r.teamName} sizeClassName="h-5 w-5" />
                    {r[nameKey]}
                  </span>
                ) : (
                  r[nameKey]
                )}
              </td>
              <td className="tabular px-3 py-2 text-right">{r.starts}</td>
              <td className="tabular px-3 py-2 text-right">{r.finished}</td>
              <td className="tabular px-3 py-2 text-right">{r.mechanical}</td>
              <td className="tabular px-3 py-2 text-right">{r.accident}</td>
              <td className="tabular px-3 py-2 text-right">{r.dnf}</td>
              <td className="tabular px-3 py-2 text-right">{r.finishRate}%</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export function ReliabilityTables({ year }: { year: number }) {
  const { data, error, isLoading } = useReliability(year);

  if (isLoading) return <LoadingState />;
  if (error) return <ErrorState message="Couldn't load reliability data." />;
  if (!data || (data.drivers.length === 0 && data.teams.length === 0))
    return <EmptyState message="No reliability data available for this season." />;

  return (
    <div className="flex flex-col gap-6">
      <ReliabilityTable title="Drivers" rows={data.drivers} nameKey="name" />
      <ReliabilityTable title="Teams" rows={data.teams} nameKey="teamName" showLogo />
    </div>
  );
}
