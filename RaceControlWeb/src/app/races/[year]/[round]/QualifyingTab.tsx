"use client";

import { useResults } from "@/lib/api";
import { LoadingState, ErrorState } from "@/components/StateViews";
import { ResultsTable } from "./ResultsTable";

export function QualifyingTab({ year, round }: { year: number; round: number }) {
  const { data, error, isLoading } = useResults(year, round, "Q");

  if (isLoading) return <LoadingState label="Loading qualifying…" />;
  if (error) return <ErrorState message="Qualifying data isn't available for this race." />;
  if (!data) return null;
  return <ResultsTable data={data} year={year} qualifying />;
}
