"use client";

import { useYearParam } from "@/lib/useYearParam";
import { useQueryParam } from "@/lib/useQueryParam";
import { SeasonPicker } from "@/components/SeasonPicker";
import { Tabs } from "@/components/Tabs";
import { DriversStandingsTable } from "./DriversStandingsTable";
import { ConstructorsStandingsTable } from "./ConstructorsStandingsTable";
import { ProgressChart } from "./ProgressChart";
import { ReliabilityTables } from "./ReliabilityTables";
import { WdcCalculatorList } from "@/components/WdcCalculatorList";

const MODES = [
  { key: "drivers", label: "Drivers" },
  { key: "constructors", label: "Constructors" },
  { key: "progress", label: "Progress" },
  { key: "reliability", label: "Reliability" },
  { key: "wdc", label: "Title Decider" },
];

export function StandingsClient({ defaultYear }: { defaultYear: number }) {
  const [year, setYear] = useYearParam(defaultYear);
  const [mode, setMode] = useQueryParam("mode", "drivers");

  return (
    <div>
      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-2xl font-bold tracking-tight">Standings</h1>
        <SeasonPicker year={year} onChange={setYear} />
      </div>

      <div className="mb-4">
        <Tabs tabs={MODES} active={mode} onChange={setMode} />
      </div>

      {mode === "drivers" && <DriversStandingsTable year={year} />}
      {mode === "constructors" && <ConstructorsStandingsTable year={year} />}
      {mode === "progress" && <ProgressChart year={year} />}
      {mode === "reliability" && <ReliabilityTables year={year} />}
      {mode === "wdc" && (
        <div className="rounded-lg border border-border bg-surface p-5">
          <WdcCalculatorList year={year} />
        </div>
      )}
    </div>
  );
}
