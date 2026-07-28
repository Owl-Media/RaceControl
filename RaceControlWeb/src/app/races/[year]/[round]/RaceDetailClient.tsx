"use client";

import { Suspense } from "react";
import { useQueryParam } from "@/lib/useQueryParam";
import { Tabs } from "@/components/Tabs";
import type { SessionResults } from "@/lib/types";
import { ResultsTable } from "./ResultsTable";
import { QualifyingTab } from "./QualifyingTab";
import { LapTimesTab } from "./LapTimesTab";
import { StrategyTab } from "./StrategyTab";
import { WeatherTab } from "./WeatherTab";
import { RetirementsTab } from "./RetirementsTab";
import { ReplayTab } from "./ReplayTab";
import { TelemetryTab } from "./TelemetryTab";
import { FlagsTab } from "./FlagsTab";
import { RaceControlTab } from "./RaceControlTab";
import { PenaltiesTab } from "./PenaltiesTab";

const TABS = [
  { key: "results", label: "Results" },
  { key: "qualifying", label: "Qualifying" },
  { key: "laptimes", label: "Lap Times" },
  { key: "strategy", label: "Strategy" },
  { key: "weather", label: "Weather" },
  { key: "retirements", label: "Retirements" },
  { key: "penalties", label: "Penalties" },
  { key: "flags", label: "Flags" },
  { key: "racecontrol", label: "Race Control" },
  { key: "telemetry", label: "Telemetry" },
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
      {tab === "laptimes" && <LapTimesTab year={year} round={round} />}
      {tab === "strategy" && <StrategyTab year={year} round={round} />}
      {tab === "weather" && <WeatherTab year={year} round={round} />}
      {tab === "retirements" && <RetirementsTab year={year} round={round} />}
      {tab === "penalties" && <PenaltiesTab year={year} round={round} />}
      {tab === "flags" && <FlagsTab year={year} round={round} />}
      {tab === "racecontrol" && <RaceControlTab year={year} round={round} />}
      {tab === "telemetry" && <TelemetryTab year={year} round={round} />}
      {tab === "replay" && <ReplayTab year={year} round={round} />}
    </div>
  );
}
