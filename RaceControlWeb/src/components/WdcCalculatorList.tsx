"use client";

import Link from "next/link";
import { useWdcCalculator } from "@/lib/api";
import { LoadingState, ErrorState, EmptyState } from "@/components/StateViews";
import { TeamLogo } from "@/components/TeamLogo";
import type { WdcDriver } from "@/lib/types";

const CAN_WIN_COLOR = "#22c55e";

// Points on offer per finishing position — the same scale the backend's
// `_CONVENTIONAL_POINTS_TOTAL` / `_SPRINT_POINTS_TOTAL` (25+1 / 8+25+1) are
// built from, shown here so the "max points" and "points still on offer"
// figures in the table below aren't just asserted, they're traceable.
const RACE_POINTS = [25, 18, 15, 12, 10, 8, 6, 4, 2, 1];
const SPRINT_POINTS = [8, 7, 6, 5, 4, 3, 2, 1];
const FASTEST_LAP_BONUS = 1; // only awarded to a top-10 finisher

/**
 * "Who can still win the WDC" — theoretical max remaining points vs. the
 * championship leader, following FastF1's own worked example:
 * https://docs.fastf1.dev/gen_modules/examples_gallery/standings/plot_who_can_still_win_wdc.html
 *
 * This is deliberately the most generous possible reading, not a realistic
 * forecast: a driver "can still win" if they could overtake the leader
 * assuming they win every remaining session AND the leader scores nothing
 * else all year. That's why most of the grid stays in contention until quite
 * late in a season — titles are rarely mathematically settled before the
 * closing rounds, once the points gap finally exceeds what's left to fight
 * over. It's a ceiling, not a prediction.
 *
 * Shared between the dashboard's top-10 preview card and the full standings
 * page's "Title Decider" tab — pass `limit` for the former, omit it for the
 * latter (the points-system reference table only renders on the full page,
 * to keep the dashboard card compact).
 */
export function WdcCalculatorList({
  year,
  limit,
  moreHref,
}: {
  year: number;
  limit?: number;
  moreHref?: string;
}) {
  const { data, isLoading, error } = useWdcCalculator(year);

  if (isLoading) return <LoadingState label="Loading title-decider…" />;
  if (error) return <ErrorState message="Couldn't load title-decider data." />;
  if (!data || data.drivers.length === 0) return <EmptyState message="No standings available yet." />;

  const rows = limit ? data.drivers.slice(0, limit) : data.drivers;
  const canWinCount = data.drivers.filter((d) => d.canWin).length;

  return (
    <div>
      <p className="mb-1 text-xs text-muted">
        {data.decided
          ? data.roundsRemaining === 0
            ? "Season complete — the title is decided."
            : "Mathematically settled — only the leader can still win."
          : `${data.roundsRemaining} round${data.roundsRemaining === 1 ? "" : "s"} left · up to ${data.maxRemainingPoints} points still on offer · ${canWinCount} driver${canWinCount === 1 ? "" : "s"} can still win`}
      </p>
      <p className="mb-3 text-xs text-muted/70">
        &quot;Can win&quot; is the best-case ceiling — winning every remaining session while the leader
        scores nothing else — not a realistic forecast.
      </p>
      <ul className="flex flex-col gap-1">
        {rows.map((d) => (
          <WdcRow key={d.driverId ?? d.driverCode ?? String(d.position)} driver={d} year={year} />
        ))}
      </ul>
      {limit && moreHref && data.drivers.length > limit && (
        <Link href={moreHref} className="mt-2 inline-block text-xs font-medium text-muted hover:text-foreground">
          View all {data.drivers.length} drivers →
        </Link>
      )}
      {!limit && <PointsSystemBreakdown />}
    </div>
  );
}

function WdcRow({ driver: d, year }: { driver: WdcDriver; year: number }) {
  const content = (
    <>
      <span className="tabular w-5 shrink-0 text-sm font-bold text-muted">{d.position ?? "—"}</span>
      <TeamLogo src={d.teamLogoUrl} name={d.teamName} sizeClassName="h-5 w-5" />
      <span className="min-w-0 flex-1 truncate text-sm font-medium sm:flex-none sm:w-36">
        {d.givenName} {d.familyName}
      </span>
      <span className="tabular hidden flex-1 text-xs text-muted sm:block">
        {d.points} pts{d.pointsBehindLeader > 0 ? ` · -${d.pointsBehindLeader}` : ""} · max {d.maxPoints}
      </span>
      <CanWinPill canWin={d.canWin} />
    </>
  );

  if (!d.driverId) {
    return <li className="flex items-center gap-2.5 rounded-md px-1.5 py-1.5">{content}</li>;
  }
  return (
    <li>
      <Link
        href={`/drivers/${year}/${d.driverId}`}
        className="flex items-center gap-2.5 rounded-md px-1.5 py-1.5 transition-colors hover:bg-surface-raised"
      >
        {content}
      </Link>
    </li>
  );
}

/**
 * A custom hover tooltip rather than the native `title` attribute — `title`
 * on an element nested inside a full-row `<Link>` is unreliable across
 * browsers (inconsistent delay, sometimes suppressed in favour of the link's
 * own hover affordance), so this renders its own, which shows immediately
 * and consistently.
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

function PointsSystemBreakdown() {
  return (
    <details className="mt-4 rounded-lg border border-border bg-surface-raised/40 p-3 text-xs text-muted">
      <summary className="cursor-pointer select-none font-medium text-foreground">
        Points breakdown — where &quot;max points&quot; comes from
      </summary>
      <div className="mt-3 flex flex-col gap-3">
        <div>
          <p className="mb-1 font-medium text-foreground">Race (top 10 score, plus +1 for fastest lap in the top 10)</p>
          <div className="flex flex-wrap gap-x-3 gap-y-1 tabular">
            {RACE_POINTS.map((pts, i) => (
              <span key={i}>
                P{i + 1} <span className="text-foreground">{pts}</span>
              </span>
            ))}
          </div>
        </div>
        <div>
          <p className="mb-1 font-medium text-foreground">Sprint (top 8 score, on sprint weekends only)</p>
          <div className="flex flex-wrap gap-x-3 gap-y-1 tabular">
            {SPRINT_POINTS.map((pts, i) => (
              <span key={i}>
                P{i + 1} <span className="text-foreground">{pts}</span>
              </span>
            ))}
          </div>
        </div>
        <p className="tabular">
          Max for one driver at a single event: race win {RACE_POINTS[0]} + fastest lap {FASTEST_LAP_BONUS} ={" "}
          <span className="font-semibold text-foreground">{RACE_POINTS[0] + FASTEST_LAP_BONUS} pts</span> on a normal
          weekend, or{" "}
          <span className="font-semibold text-foreground">
            {RACE_POINTS[0] + FASTEST_LAP_BONUS + SPRINT_POINTS[0]} pts
          </span>{" "}
          on a sprint weekend (+ sprint win {SPRINT_POINTS[0]}). &quot;Max remaining points&quot; above is this figure
          multiplied out across every round still left on the calendar.
        </p>
      </div>
    </details>
  );
}
