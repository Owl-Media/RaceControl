"use client";

import Link from "next/link";
import clsx from "clsx";
import { useYearParam } from "@/lib/useYearParam";
import { useSchedule } from "@/lib/api";
import { SeasonPicker } from "@/components/SeasonPicker";
import { LoadingState, ErrorState, EmptyState } from "@/components/StateViews";
import { formatDate } from "@/lib/format";

export function ScheduleClient({ defaultYear }: { defaultYear: number }) {
  const [year, setYear] = useYearParam(defaultYear);
  const { data: events, error, isLoading } = useSchedule(year);

  return (
    <div>
      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-2xl font-bold tracking-tight">Race Schedule</h1>
        <SeasonPicker year={year} onChange={setYear} />
      </div>

      {isLoading && <LoadingState label="Loading schedule…" />}
      {error && <ErrorState message="Couldn't load the schedule." />}
      {events && events.length === 0 && <EmptyState message="No races scheduled for this season." />}

      {events && events.length > 0 && (
        <ol className="flex flex-col gap-2">
          {events
            .filter((e) => e.round > 0)
            .map((event) => (
              <li key={event.round}>
                <Link
                  href={`/races/${year}/${event.round}`}
                  className="flex items-center gap-4 rounded-lg border border-border bg-surface px-4 py-3 transition-colors hover:bg-surface-raised"
                >
                  <span className="tabular w-8 shrink-0 text-sm text-muted">R{event.round}</span>
                  <div className="min-w-0 flex-1">
                    <p className="truncate font-medium">{event.name}</p>
                    <p className="truncate text-sm text-muted">
                      {event.location}, {event.country}
                    </p>
                  </div>
                  <span
                    className={clsx(
                      "tabular shrink-0 text-sm",
                      event.completed ? "text-muted" : "font-medium text-foreground",
                    )}
                  >
                    {formatDate(event.date)}
                  </span>
                  {!event.completed && (
                    <span className="shrink-0 rounded-full bg-racing-red/15 px-2 py-0.5 text-xs font-semibold text-racing-red">
                      Upcoming
                    </span>
                  )}
                </Link>
              </li>
            ))}
        </ol>
      )}
    </div>
  );
}
