import Link from "next/link";
import { callBackend, BackendError } from "@/lib/server/backend";
import type { Team } from "@/lib/types";
import { TeamColorDot } from "@/components/StateViews";
import { driverInitials } from "@/lib/format";
import { TeamFavoriteButton } from "./TeamFavoriteButton";

export default async function TeamDetailPage({
  params,
}: {
  params: Promise<{ year: string; teamId: string }>;
}) {
  const { year, teamId } = await params;
  let team: Team;
  try {
    team = await callBackend<Team>(`/api/teams/${year}/${teamId}`);
  } catch (e) {
    const message = e instanceof BackendError ? e.message : "Couldn't load this team.";
    return <div className="rounded-lg border border-border bg-surface px-4 py-6 text-sm text-muted">{message}</div>;
  }

  return (
    <div>
      <Link href={`/teams?year=${year}`} className="mb-4 inline-block text-sm text-muted hover:text-foreground">
        ← Teams
      </Link>

      <div
        className="mb-6 flex items-center gap-4 rounded-lg border border-border bg-surface p-4"
        style={{ borderLeft: `4px solid ${team.teamColor || "var(--border)"}` }}
      >
        <TeamColorDot color={team.teamColor} />
        <div className="min-w-0 flex-1">
          <h1 className="text-xl font-bold">{team.teamName}</h1>
          <p className="text-sm text-muted">{team.nationality ?? "—"}</p>
        </div>
        <div className="text-right">
          <p className="tabular text-2xl font-bold">{team.points ?? 0}</p>
          <p className="text-xs uppercase tracking-wide text-muted">pts · P{team.position ?? "—"} · {team.wins ?? 0} wins</p>
        </div>
        <TeamFavoriteButton teamId={team.teamId} name={team.teamName ?? teamId} />
      </div>

      <h2 className="mb-3 text-lg font-semibold">Drivers</h2>
      <ul className="grid grid-cols-1 gap-2 sm:grid-cols-2">
        {team.drivers.map((d) => (
          <li key={d.driverId}>
            <Link
              href={`/drivers/${year}/${d.driverId}`}
              className="flex items-center gap-3 rounded-lg border border-border bg-surface px-4 py-3 transition-colors hover:bg-surface-raised"
            >
              {d.headshotUrl ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={d.headshotUrl} alt="" className="h-10 w-10 rounded-full object-cover" />
              ) : (
                <span className="flex h-10 w-10 items-center justify-center rounded-full bg-surface-raised text-xs font-semibold text-muted">
                  {driverInitials(d.name)}
                </span>
              )}
              <div className="min-w-0 flex-1">
                <p className="truncate font-medium">{d.name}</p>
                <p className="text-sm text-muted">
                  {d.code ?? "—"} · #{d.number ?? "—"}
                </p>
              </div>
            </Link>
          </li>
        ))}
      </ul>
    </div>
  );
}
