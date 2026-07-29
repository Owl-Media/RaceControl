"use client";

import Link from "next/link";
import { useWdcCalculator } from "@/lib/api";
import { LoadingState, ErrorState, EmptyState } from "@/components/StateViews";
import { TeamColorDot } from "@/components/StateViews";
import { TeamLogo } from "@/components/TeamLogo";
import { WdcPointsBreakdown } from "@/components/WdcPointsBreakdown";
import type { WdcDriver } from "@/lib/types";

const CAN_WIN_COLOR = "#22c55e";

/**
 * Full "who can still win the WDC" table for the Standings page's Title
 * Decider tab — formatted like the other data tables in the app (Results,
 * Qualifying) with column headers, rather than the dashboard card's compact
 * row-list, since this is the detail view rather than a preview.
 *
 * See WdcCalculatorList.tsx for the method this is built on (FastF1's own
 * "who can still win the WDC" worked example) and its caveats.
 */
export function WdcCalculatorTable({ year }: { year: number }) {
  const { data, isLoading, error } = useWdcCalculator(year);

  if (isLoading) return <LoadingState label="Loading title-decider…" />;
  if (error) return <ErrorState message="Couldn't load title-decider data." />;
  if (!data || data.drivers.length === 0) return <EmptyState message="No standings available yet." />;

  const canWinCount = data.drivers.filter((d) => d.canWin).length;

  return (
    <div>
      <p className="mb-1 text-sm text-muted">
        {data.decided
          ? data.roundsRemaining === 0
            ? "Season complete — the title is decided."
            : "Mathematically settled — only the leader can still win."
          : `${data.roundsRemaining} round${data.roundsRemaining === 1 ? "" : "s"} left · up to ${data.maxRemainingPoints} points still on offer · ${canWinCount} driver${canWinCount === 1 ? "" : "s"} can still win`}
      </p>
      <p className="mb-4 text-xs text-muted/70">
        &quot;Can win&quot; is the best-case ceiling — winning every remaining session while the leader
        scores nothing else — not a realistic forecast.
      </p>

      <div className="overflow-x-auto rounded-lg border border-border">
        <table className="w-full text-sm">
          <thead className="bg-surface text-left text-xs uppercase tracking-wide text-muted">
            <tr>
              <th className="px-3 py-2 font-medium">Pos</th>
              <th className="px-3 py-2 font-medium">Driver</th>
              <th className="px-3 py-2 font-medium">Team</th>
              <th className="tabular px-3 py-2 text-right font-medium">Points</th>
              <th className="tabular px-3 py-2 text-right font-medium">Behind Leader</th>
              <th className="tabular px-3 py-2 text-right font-medium">Max Possible</th>
              <th className="px-3 py-2 text-right font-medium">Title Status</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-border">
            {data.drivers.map((d, i) => (
              <WdcTableRow key={d.driverId ?? d.driverCode ?? `${d.position}-${i}`} driver={d} year={year} />
            ))}
          </tbody>
        </table>
      </div>

      <WdcPointsBreakdown />
    </div>
  );
}

function WdcTableRow({ driver: d, year }: { driver: WdcDriver; year: number }) {
  return (
    <tr className="hover:bg-surface/60">
      <td className="tabular px-3 py-2 text-muted">{d.position ?? "—"}</td>
      <td className="px-3 py-2 font-medium">
        {d.driverId ? (
          <Link href={`/drivers/${year}/${d.driverId}`} className="hover:text-racing-red">
            {d.givenName} {d.familyName}
          </Link>
        ) : (
          `${d.givenName ?? ""} ${d.familyName ?? ""}`.trim() || "—"
        )}
      </td>
      <td className="px-3 py-2 text-muted">
        <span className="inline-flex items-center gap-2">
          <TeamColorDot color={d.teamColor} />
          <TeamLogo src={d.teamLogoUrl} name={d.teamName} sizeClassName="h-4 w-4" />
          {d.teamName ?? "—"}
        </span>
      </td>
      <td className="tabular px-3 py-2 text-right font-semibold">{d.points}</td>
      <td className="tabular px-3 py-2 text-right text-muted">{d.pointsBehindLeader > 0 ? `-${d.pointsBehindLeader}` : "Leader"}</td>
      <td className="tabular px-3 py-2 text-right text-muted">{d.maxPoints}</td>
      <td className="px-3 py-2 text-right">
        <CanWinPill canWin={d.canWin} />
      </td>
    </tr>
  );
}

/**
 * A custom hover tooltip rather than the native `title` attribute — `title`
 * on an element nested inside a link/row is unreliable across browsers, so
 * this renders its own, which shows immediately and consistently.
 */
function CanWinPill({ canWin }: { canWin: boolean }) {
  return (
    <span className="group relative inline-flex shrink-0">
      <span
        className="rounded-full px-2 py-0.5 text-xs font-semibold"
        style={
          canWin
            ? { backgroundColor: `${CAN_WIN_COLOR}26`, color: CAN_WIN_COLOR }
            : { backgroundColor: "var(--surface-raised)", color: "var(--muted)" }
        }
      >
        {canWin ? "Can win" : "Can't win"}
      </span>
      <span
        role="tooltip"
        className="pointer-events-none absolute bottom-full right-0 z-10 mb-1.5 w-44 rounded-md border border-border bg-surface-raised px-2 py-1.5 text-[11px] leading-snug text-muted opacity-0 shadow-lg transition-opacity group-hover:opacity-100"
      >
        {canWin
          ? "Could still overtake the leader in the best possible case."
          : "No longer mathematically possible, even in the best case."}
      </span>
    </span>
  );
}
