import Link from "next/link";
import { callBackend, BackendError } from "@/lib/server/backend";
import type { SessionResults } from "@/lib/types";
import { RaceDetailClient } from "./RaceDetailClient";

export default async function RaceDetailPage({
  params,
}: {
  params: Promise<{ year: string; round: string }>;
}) {
  const { year, round } = await params;
  const y = parseInt(year, 10);
  const r = parseInt(round, 10);

  let results: SessionResults | null = null;
  try {
    results = await callBackend<SessionResults>(`/api/results/${y}/${r}/R`);
  } catch (e) {
    const message = e instanceof BackendError ? e.message : "Couldn't load this race.";
    return <div className="rounded-lg border border-border bg-surface px-4 py-6 text-sm text-muted">{message}</div>;
  }

  return (
    <div>
      <Link href={`/schedule?year=${y}`} className="mb-4 inline-block text-sm text-muted hover:text-foreground">
        ← Schedule
      </Link>
      <h1 className="mb-6 text-2xl font-bold tracking-tight">{results.eventName}</h1>
      <RaceDetailClient year={y} round={r} initialResults={results} />
    </div>
  );
}
