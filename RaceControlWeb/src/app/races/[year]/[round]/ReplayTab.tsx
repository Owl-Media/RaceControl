"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import clsx from "clsx";
import { motion, AnimatePresence } from "motion/react";
import { useReplay, useReplayPositions, useCircuitMap } from "@/lib/api";
import { LoadingState, ErrorState, EmptyState, TeamColorDot } from "@/components/StateViews";
import { TeamLogo } from "@/components/TeamLogo";
import { TyreLegend } from "@/components/TyreLegend";
import { compoundColor } from "@/lib/tyres";
import { REPLAY_TICK_MS } from "@/lib/replay";
import { useLocalStorageFlag } from "@/lib/useLocalStorageFlag";
import { useMediaQuery } from "@/lib/useMediaQuery";
import type { ReplayLapPositions } from "@/lib/types";
import { ReplayTrackMap } from "./ReplayTrackMap";

export function ReplayTab({ year, round }: { year: number; round: number }) {
  const { data, error, isLoading } = useReplay(year, round);
  // The track outline and the car positions are separate requests from the
  // replay itself and resolve later, so their loading state has to be passed
  // down, otherwise the map reports "no data" during its own fetch.
  const { data: circuit, isLoading: circuitLoading } = useCircuitMap(year, round);
  const { data: positions, isLoading: positionsLoading } = useReplayPositions(year, round);
  const [lapIndex, setLapIndex] = useState(0);
  const [playing, setPlaying] = useState(false);
  // Only affects the stacked (mobile) layout; on `lg` and up the map lives in
  // its own column and is always shown.
  const [mapCollapsed, setMapCollapsed] = useLocalStorageFlag("replay:map-collapsed", false);
  // `mapCollapsed` only actually hides the map below `lg` (see the `hidden
  // lg:block` class below); on desktop it's always visible regardless. The
  // map runs a per-frame animation loop while playing, so this tells it
  // whether it's really on screen and worth animating, rather than always
  // running that loop even while CSS-hidden on a phone.
  const isDesktopLayout = useMediaQuery("(min-width: 1024px)");
  const mapVisible = isDesktopLayout || !mapCollapsed;

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

      {/* Desktop puts the map and the running order side by side so neither
          has to be hidden, with the map sticky so it stays in view while the
          order is scrolled. Below `lg` there isn't room for two columns, so
          the map stacks and can be collapsed away instead. */}
      <div className="lg:grid lg:grid-cols-2 lg:items-start lg:gap-6">
        <div className="lg:sticky lg:top-6">
          <div className="mb-2 flex justify-end lg:hidden">
            <button
              type="button"
              onClick={() => setMapCollapsed(!mapCollapsed)}
              aria-expanded={!mapCollapsed}
              className="rounded-md border border-border px-2.5 py-1 text-xs font-medium text-muted transition-colors hover:text-foreground"
            >
              {mapCollapsed ? "Show map" : "Hide map"}
            </button>
          </div>
          <div className={clsx("mb-4", mapCollapsed && "hidden lg:block")}>
            <ReplayTrackMap
              circuit={circuit}
              circuitLoading={circuitLoading}
              positionsLoading={positionsLoading}
              lapPositions={frame ? positionsByLap.get(frame.lap) : undefined}
              driverTeamColors={driverTeamColors}
              playing={playing}
              active={mapVisible}
            />
          </div>
        </div>

        <div>
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
                  <TeamLogo src={entry.teamLogoUrl} name={entry.teamName} sizeClassName="h-5 w-5" />
                  {entry.driverId ? (
                    <Link
                      href={`/drivers/${year}/${entry.driverId}`}
                      className="w-14 shrink-0 font-medium hover:text-racing-red"
                    >
                      {entry.driver}
                    </Link>
                  ) : (
                    <span className="w-14 shrink-0 font-medium">{entry.driver}</span>
                  )}
                  <span className="min-w-0 flex-1 truncate text-sm text-muted">{entry.teamName}</span>
                  {entry.compound && (
                    <span
                      className="h-2.5 w-2.5 shrink-0 rounded-full"
                      style={{ backgroundColor: compoundColor(entry.compound) }}
                      title={entry.compound}
                    />
                  )}
                  <span className="tabular w-20 shrink-0 text-right text-sm text-muted">{entry.lapTime ?? "-"}</span>
                </motion.li>
              ))}
            </AnimatePresence>
          </ul>
        </div>
      </div>
    </div>
  );
}
