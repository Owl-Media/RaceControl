"use client";

import { Suspense } from "react";
import { useQueryParam } from "@/lib/useQueryParam";
import { Tabs } from "@/components/Tabs";
import type { SessionResults } from "@/lib/types";
import { ResultsTable } from "./ResultsTable";
import { QualifyingTab } from "./QualifyingTab";
import { QualifyingLadderTab } from "./QualifyingLadderTab";
import { LapTimesTab } from "./LapTimesTab";
import { RaceTraceTab } from "./RaceTraceTab";
import { PositionChartTab } from "./PositionChartTab";
import { TyrePerformanceTab } from "./TyrePerformanceTab";
import { PitStopsTab } from "./PitStopsTab";
import { PitSwimlaneTab } from "./PitSwimlaneTab";
import { QualifyingSectorsTab } from "./QualifyingSectorsTab";
import { SpeedTrapTab } from "./SpeedTrapTab";
import { MiniSectorsTab } from "./MiniSectorsTab";
import { StrategyTab } from "./StrategyTab";
import { WeatherTab } from "./WeatherTab";
import { RetirementsTab } from "./RetirementsTab";
import { ReplayTab } from "./ReplayTab";
import { TelemetryTab } from "./TelemetryTab";
import { BrakeThrottleTab } from "./BrakeThrottleTab";
import { FlagsTab } from "./FlagsTab";
import { RaceControlTab } from "./RaceControlTab";
import { PenaltiesTab } from "./PenaltiesTab";

const TABS = [
  { key: "results", label: "Results" },
  { key: "qualifying", label: "Qualifying" },
  { key: "qualifyingladder", label: "Qualifying Ladder" },
  { key: "laptimes", label: "Lap Times" },
  { key: "racetrace", label: "Race Trace" },
  { key: "positions", label: "Positions" },
  { key: "tyreperformance", label: "Tyre Degradation" },
  { key: "pitstops", label: "Pit Stops" },
  { key: "pitswimlane", label: "Pit Swimlane" },
  { key: "qualifyingsectors", label: "Sector Waterfall" },
  { key: "speedtrap", label: "Speed Trap" },
  { key: "minisectors", label: "Mini-Sectors" },
  { key: "strategy", label: "Strategy" },
  { key: "weather", label: "Weather" },
  { key: "retirements", label: "Retirements" },
  { key: "penalties", label: "Penalties" },
  { key: "flags", label: "Flags" },
  { key: "racecontrol", label: "Race Control" },
  { key: "telemetry", label: "Telemetry" },
  { key: "brakethrottle", label: "Brake/Throttle" },
  { key: "replay", label: "Replay" },
];

export function RaceDetailClient({
  year,
  round,
  initialResults,
}: {
  year: number;
  round: number;
  initialResults: SessionResults;
}) {
  const [tab, setTab] = useQueryParam("tab", "results");

  return (
    <div>
      <div className="mb-4">
        <Suspense fallback={null}>
          <Tabs tabs={TABS} active={tab} onChange={setTab} />
        </Suspense>
      </div>
      {tab === "results" && <ResultsTable data={initialResults} year={year} />}
      {tab === "qualifying" && <QualifyingTab year={year} round={round} />}
      {tab === "qualifyingladder" && <QualifyingLadderTab year={year} round={round} />}
      {tab === "laptimes" && <LapTimesTab year={year} round={round} />}
      {tab === "racetrace" && <RaceTraceTab year={year} round={round} />}
      {tab === "positions" && <PositionChartTab year={year} round={round} />}
      {tab === "tyreperformance" && <TyrePerformanceTab year={year} round={round} />}
      {tab === "pitstops" && <PitStopsTab year={year} round={round} />}
      {tab === "pitswimlane" && <PitSwimlaneTab year={year} round={round} />}
      {tab === "qualifyingsectors" && <QualifyingSectorsTab year={year} round={round} />}
      {tab === "speedtrap" && <SpeedTrapTab year={year} round={round} />}
      {tab === "minisectors" && <MiniSectorsTab year={year} round={round} />}
      {tab === "strategy" && <StrategyTab year={year} round={round} />}
      {tab === "weather" && <WeatherTab year={year} round={round} />}
      {tab === "retirements" && <RetirementsTab year={year} round={round} />}
      {tab === "penalties" && <PenaltiesTab year={year} round={round} />}
      {tab === "flags" && <FlagsTab year={year} round={round} />}
      {tab === "racecontrol" && <RaceControlTab year={year} round={round} />}
      {tab === "telemetry" && <TelemetryTab year={year} round={round} />}
      {tab === "brakethrottle" && <BrakeThrottleTab year={year} round={round} />}
      {tab === "replay" && <ReplayTab year={year} round={round} />}
    </div>
  );
}
