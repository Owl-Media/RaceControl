"use client";

import useSWR, { SWRConfiguration } from "swr";
import type {
  CircuitMap,
  Circuit,
  CompareResponse,
  ConstructorStanding,
  DriverDetail,
  DriverStanding,
  Driver,
  FlagsResponse,
  LapTimesResponse,
  RaceDriver,
  RaceReplay,
  ReplayPositions,
  RaceControlResponse,
  ReliabilityResponse,
  RetirementsResponse,
  ScheduleEvent,
  SessionResults,
  StandingsEvolutionResponse,
  StrategyResponse,
  Team,
  TelemetryCompareResponse,
  TelemetryResponse,
  WeatherResponse,
} from "@/lib/types";

function buildPath(path: string, params?: Record<string, string | number | undefined>): string {
  const url = new URL("/api/proxy" + path, "http://placeholder");
  if (params) {
    for (const [key, value] of Object.entries(params)) {
      if (value !== undefined) url.searchParams.set(key, String(value));
    }
  }
  return url.pathname + url.search;
}

async function fetcher<T>(url: string): Promise<T> {
  const res = await fetch(url);
  if (!res.ok) {
    const body = await res.text().catch(() => "");
    throw new Error(body || `Request failed: ${res.status}`);
  }
  return res.json();
}

function useApi<T>(path: string | null, params?: Record<string, string | number | undefined>, config?: SWRConfiguration) {
  const key = path ? buildPath(path, params) : null;
  return useSWR<T>(key, fetcher, config);
}

export const useSeasons = () => useApi<number[]>("/api/seasons");
export const useSchedule = (year: number) => useApi<ScheduleEvent[]>(`/api/schedule/${year}`);
export const useResults = (year: number, rnd: number, session: string) =>
  useApi<SessionResults>(`/api/results/${year}/${rnd}/${session}`);
export const useDriverStandings = (year: number) => useApi<DriverStanding[]>(`/api/standings/drivers/${year}`);
export const useConstructorStandings = (year: number) =>
  useApi<ConstructorStanding[]>(`/api/standings/constructors/${year}`);
export const useDrivers = (year: number) => useApi<Driver[]>(`/api/drivers/${year}`);
export const useDriverDetail = (year: number, driverId: string | null) =>
  useApi<DriverDetail>(driverId ? `/api/drivers/${year}/${driverId}` : null);
export const useTeams = (year: number) => useApi<Team[]>(`/api/teams/${year}`);
export const useTeamDetail = (year: number, teamId: string | null) =>
  useApi<Team>(teamId ? `/api/teams/${year}/${teamId}` : null);
export const useCircuits = (year: number) => useApi<Circuit[]>(`/api/circuits/${year}`);
export const useCircuitMap = (year: number, rnd: number) => useApi<CircuitMap>(`/api/circuit/${year}/${rnd}`);
export const useReplay = (year: number, rnd: number) => useApi<RaceReplay>(`/api/replay/${year}/${rnd}`);
export const useReplayPositions = (year: number, rnd: number) =>
  useApi<ReplayPositions>(`/api/replay-positions/${year}/${rnd}`);
export const useLapTimes = (year: number, rnd: number) => useApi<LapTimesResponse>(`/api/laptimes/${year}/${rnd}`);
export const useStrategy = (year: number, rnd: number) => useApi<StrategyResponse>(`/api/strategy/${year}/${rnd}`);
export const useWeather = (year: number, rnd: number, session: string) =>
  useApi<WeatherResponse>(`/api/weather/${year}/${rnd}/${session}`);
export const useRaceDrivers = (year: number, rnd: number) => useApi<RaceDriver[]>(`/api/racedrivers/${year}/${rnd}`);
export const useTelemetry = (year: number, rnd: number, driver: string | null, lap = "fastest") =>
  useApi<TelemetryResponse>(driver ? `/api/telemetry/${year}/${rnd}/${driver}` : null, { lap });
export const useTelemetryCompare = (year: number, rnd: number, d1: string | null, d2: string | null) =>
  useApi<TelemetryCompareResponse>(d1 && d2 ? `/api/telemetry-compare/${year}/${rnd}` : null, { d1: d1 ?? undefined, d2: d2 ?? undefined });
export const useRetirements = (year: number, rnd: number) => useApi<RetirementsResponse>(`/api/retirements/${year}/${rnd}`);
export const useFlags = (year: number, rnd: number, session = "R") =>
  useApi<FlagsResponse>(`/api/flags/${year}/${rnd}`, { session });
export const useRaceControl = (year: number, rnd: number, session = "R") =>
  useApi<RaceControlResponse>(`/api/racecontrol/${year}/${rnd}`, { session });
export const useReliability = (year: number) => useApi<ReliabilityResponse>(`/api/reliability/${year}`);
export const useCompare = (year: number, d1: string | null, d2: string | null) =>
  useApi<CompareResponse>(d1 && d2 ? `/api/compare/${year}/${d1}/${d2}` : null);
export const useStandingsEvolution = (year: number) =>
  useApi<StandingsEvolutionResponse>(`/api/standings-evolution/${year}`);
