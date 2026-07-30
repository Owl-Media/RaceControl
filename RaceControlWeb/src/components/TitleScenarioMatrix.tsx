"use client";

import { useTitleScenarios } from "@/lib/api";

const outcomeColor: Record<string, string> = {
  D1_CLINCHED: "#30d158",
  D2_CLINCHED: "#ff453a",
  D1_LEADS: "#14532d",
  D2_LEADS: "#7f1d1d",
  TIED: "#6b7280",
};

export function TitleScenarioMatrix({ year }: { year: number }) {
  const { data } = useTitleScenarios(year);
  if (!data?.available || data.drivers.length < 2) return null;
  const label = (position: number) => (position === 0 ? "DNF" : `P${position}`);

  return (
    <section className="mt-6">
      <h3 className="mb-1 font-semibold">Title Permutations</h3>
      <p className="mb-3 text-xs text-muted">
        Rows: {data.drivers[0].code}. Columns: {data.drivers[1].code}. Cell colour shows the championship state after the next race.
      </p>
      {data.clinchText && <p className="mb-3 rounded-md bg-positive/10 p-3 text-sm">{data.clinchText}</p>}
      <div className="overflow-x-auto">
        <div className="grid min-w-[620px] gap-1" style={{ gridTemplateColumns: `54px repeat(${data.positions.length}, minmax(44px, 1fr))` }}>
          <span />
          {data.positions.map((position) => <span key={position} className="text-center text-[10px] text-muted">{label(position)}</span>)}
          {data.positions.map((row) => (
            <div key={row} className="contents">
              <span className="self-center text-xs text-muted">{label(row)}</span>
              {data.positions.map((column) => {
                const cell = data.cells.find((item) => item.d1Position === row && item.d2Position === column);
                return (
                  <div
                    key={`${row}-${column}`}
                    className="aspect-square rounded-sm border border-white/5"
                    style={{ backgroundColor: outcomeColor[cell?.outcome ?? "TIED"] }}
                    title={cell ? `${label(row)} / ${label(column)}: ${cell.outcome.replaceAll("_", " ")} (${cell.margin > 0 ? "+" : ""}${cell.margin})` : ""}
                  />
                );
              })}
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
