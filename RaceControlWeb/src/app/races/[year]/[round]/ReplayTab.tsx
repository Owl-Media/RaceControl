"use client";

import { useEffect, useState } from "react";
import { motion, AnimatePresence } from "motion/react";
import { useReplay } from "@/lib/api";
import { LoadingState, ErrorState, EmptyState, TeamColorDot } from "@/components/StateViews";
import { compoundColor } from "@/lib/tyres";

export function ReplayTab({ year, round }: { year: number; round: number }) {
  const { data, error, isLoading } = useReplay(year, round);
  const [lapIndex, setLapIndex] = useState(0);
  const [playing, setPlaying] = useState(false);

  const frames = data?.frames ?? [];
  const frame = frames[lapIndex];

  useEffect(() => {
    if (!playing || frames.length === 0) return;
    const id = setInterval(() => {
      setLapIndex((i) => {
        if (i >= frames.length - 1) {
          setPlaying(false);
          return i;
        }
        return i + 1;
      });
    }, 700);
    return () => clearInterval(id);
  }, [playing, frames.length]);

  if (isLoading) return <LoadingState label="Loading replay…" />;
  if (error) return <ErrorState message="Replay data isn't available for this race." />;
  if (!data || frames.length === 0) return <EmptyState message="No replay data available." />;

  return (
    <div>
      <div className="mb-4 flex items-center gap-3">
        <button
          type="button"
          onClick={() => setPlaying((p) => !p)}
          className="rounded-md bg-racing-red px-4 py-1.5 text-sm font-semibold text-white"
        >
          {playing ? "Pause" : "Play"}
        </button>
        <input
          type="range"
          min={0}
          max={frames.length - 1}
          value={lapIndex}
          onChange={(e) => {
            setPlaying(false);
            setLapIndex(parseInt(e.target.value, 10));
          }}
          className="flex-1 accent-[color:var(--racing-red)]"
        />
        <span className="tabular w-24 shrink-0 text-right text-sm text-muted">
          Lap {frame?.lap ?? 0} / {data.totalLaps}
        </span>
      </div>

      <ul className="flex flex-col gap-1.5">
        <AnimatePresence initial={false}>
          {frame?.order.map((entry) => (
            <motion.li
              key={entry.driver}
              layout
              transition={{ type: "spring", stiffness: 400, damping: 35 }}
              className="flex items-center gap-3 rounded-lg border border-border bg-surface px-3 py-2"
            >
              <span className="tabular w-6 shrink-0 text-center font-semibold">{entry.position}</span>
              <TeamColorDot color={entry.teamColor} />
              <span className="w-14 shrink-0 font-medium">{entry.driver}</span>
              <span className="min-w-0 flex-1 truncate text-sm text-muted">{entry.teamName}</span>
              {entry.compound && (
                <span
                  className="h-2.5 w-2.5 shrink-0 rounded-full"
                  style={{ backgroundColor: compoundColor(entry.compound) }}
                  title={entry.compound}
                />
              )}
              <span className="tabular w-20 shrink-0 text-right text-sm text-muted">{entry.lapTime ?? "—"}</span>
            </motion.li>
          ))}
        </AnimatePresence>
      </ul>
    </div>
  );
}
