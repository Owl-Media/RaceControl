"use client";

import Link from "next/link";
import { formatMs } from "@/lib/format";
import { TeamColorDot } from "@/components/StateViews";
import { TeamLogo } from "@/components/TeamLogo";
import type { SessionResults } from "@/lib/types";

export function ResultsTable({ data, year, qualifying = false }: { data: SessionResults; year: number; qualifying?: boolean }) {
  if (data.results.length === 0) {
    return (
      <div className="rounded-lg border border-dashed border-border px-4 py-10 text-center text-sm text-muted">
        No results available yet.
      </div>
    );
  }

  return (
    <div className="overflow-x-auto rounded-lg border border-border">
      <table className="w-full text-sm">
        <thead className="bg-surface text-left text-xs uppercase tracking-wide text-muted">
          <tr>
            <th className="px-3 py-2 font-medium">Pos</th>
            <th className="px-3 py-2 font-medium">Driver</th>
            <th className="px-3 py-2 font-medium">Team</th>
            {qualifying ? (
              <>
                <th className="tabular px-3 py-2 text-right font-medium">Q1</th>
                <th className="tabular px-3 py-2 text-right font-medium">Q2</th>
                <th className="tabular px-3 py-2 text-right font-medium">Q3</th>
              </>
            ) : (
              <>
                <th className="tabular px-3 py-2 text-right font-medium">Grid</th>
                <th className="px-3 py-2 font-medium">Status</th>
                <th className="tabular px-3 py-2 text-right font-medium">Time</th>
                <th className="tabular px-3 py-2 text-right font-medium">Pts</th>
              </>
            )}
          </tr>
        </thead>
        <tbody className="divide-y divide-border">
          {data.results.map((r, i) => (
            // `driverId`/`driverNumber` can both be missing or duplicated for
            // reserve/no-time entries (and some upstream rows arrive with a
            // literal "nan" string rather than a real value) — fold in the
            // row index so the key is always unique regardless of what the
            // data actually contains.
            <tr key={`${r.driverId ?? r.driverNumber ?? "row"}-${i}`} className="hover:bg-surface/60">
              <td className="tabular px-3 py-2 text-muted">{r.classifiedPosition ?? r.position ?? "—"}</td>
              <td className="px-3 py-2 font-medium">
                {r.driverId ? (
                  <Link href={`/drivers/${year}/${r.driverId}`} className="hover:text-racing-red">
                    {r.fullName ?? r.abbreviation}
                  </Link>
                ) : (
                  (r.fullName ?? r.abbreviation)
                )}
              </td>
              <td className="px-3 py-2 text-muted">
                <span className="inline-flex items-center gap-2">
                  <TeamColorDot color={r.teamColor} />
                  <TeamLogo src={r.teamLogoUrl} name={r.teamName} sizeClassName="h-4 w-4" />
                  {r.teamName ?? "—"}
                </span>
              </td>
              {qualifying ? (
                <>
                  <td className="tabular px-3 py-2 text-right">{r.q1 ?? "—"}</td>
                  <td className="tabular px-3 py-2 text-right">{r.q2 ?? "—"}</td>
                  <td className="tabular px-3 py-2 text-right">{r.q3 ?? "—"}</td>
                </>
              ) : (
                <>
                  <td className="tabular px-3 py-2 text-right">{r.gridPosition ?? "—"}</td>
                  <td className="px-3 py-2 text-muted">{r.status ?? "—"}</td>
                  <td className="tabular px-3 py-2 text-right">{r.timeMs ? formatMs(r.timeMs) : "—"}</td>
                  <td className="tabular px-3 py-2 text-right font-semibold">{r.points ?? 0}</td>
                </>
              )}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
