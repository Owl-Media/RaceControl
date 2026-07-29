"use client";

import Link from "next/link";
import { useWdcCalculator } from "@/lib/api";
import { LoadingState, ErrorState, EmptyState } from "@/components/StateViews";
import { TeamLogo } from "@/components/TeamLogo";
import type { WdcDriver } from "@/lib/types";

const CAN_WIN_COLOR = "#22c55e";

/**
 * "Who can still win the WDC" — theoretical max remaining points vs. the
 * championship leader, following FastF1's own worked example:
 * https://docs.fastf1.dev/gen_modules/examples_gallery/standings/plot_who_can_still_win_wdc.html
 *
 * Shared between the dashboard's top-10 preview card and the full standings
 * page's "Title Decider" tab — pass `limit` for the former, omit it for the
 * latter.
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

  return (
    <div>
      <p className="mb-3 text-xs text-muted">
        {data.decided
          ? data.roundsRemaining === 0
            ? "Season complete — the title is decided."
            : "Mathematically decided — only the leader can still win."
          : `${data.roundsRemaining} round${data.roundsRemaining === 1 ? "" : "s"} left · up to ${data.maxRemainingPoints} points still on offer`}
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
      <span
        className="shrink-0 rounded-full px-2 py-0.5 text-xs font-semibold"
        style={
          d.canWin
            ? { backgroundColor: `${CAN_WIN_COLOR}26`, color: CAN_WIN_COLOR }
            : { backgroundColor: "var(--surface-raised)", color: "var(--muted)" }
        }
      >
        {d.canWin ? "Can win" : "Out"}
      </span>
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
