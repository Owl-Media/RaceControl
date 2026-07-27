"use client";

import { useEffect, useMemo, useState } from "react";
import { motion, AnimatePresence } from "motion/react";
import { useReplay, useReplayPositions, useCircuitMap } from "@/lib/api";
import { LoadingState, ErrorState, EmptyState, TeamColorDot } from "@/components/StateViews";
import { TyreLegend } from "@/components/TyreLegend";
import { compoundColor } from "@/lib/tyres";
import { REPLAY_TICK_MS } from "@/lib/replay";
import type { ReplayLapPositions } from "@/lib/types";
import { ReplayTrackMap } from "./ReplayTrackMap";

export function ReplayTab({ year, round }: { year: number; round: number }) {
  const { data, error, isLoading } = useReplay(year, round);
  // The track outline and the car positions are separate requests from the
  // replay itself and resolve later, so their loading state has to be passed
  // down — otherwise the map reports "no data" during its own fetch.
  const { data: circuit, isLoading: circuitLoading } = useCircuitMap(year, round);
  const { data: positions, isLoading: positionsLoading } = useReplayPositions(year, round);
  const [lapIndex, setLapIndex] = useState(0);
  const [playing, setPlaying] = useState(false);

  const frames = data?.frames ?? [];
  const frame = frames[lapIndex];

  const positionsByLap = useMemo(() => {
    const map = new Map<number, ReplayLapPositions>();
    for (const lp of positions?.laps ?? []) map.set(lp.lap, lp);
    return map;
  }, [positions]);

  const driverTeamColors = useMemo(() => {
    const out: Record<string, string | null> = {};
    for (const d of data?.drivers ?? []) out[d.code] = d.teamColor;
    return out;
  }, [data]);

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
    }, REPLAY_TICK_MS);
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

      <div className="mb-4">
        <ReplayTrackMap
          circuit={circuit}
          circuitLoading={circuitLoading}
          positionsLoading={positionsLoading}
          lapPositions={frame ? positionsByLap.get(frame.lap) : undefined}
          driverTeamColors={driverTeamColors}
          playing={playing}
        />
      </div>

      <div className="mb-3">
        <TyreLegend />
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
