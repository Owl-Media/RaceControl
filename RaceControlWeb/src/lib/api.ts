"use client";

import useSWR, { SWRConfiguration, preload } from "swr";
import type {
  CircuitMap,
  Circuit,
  CompareResponse,
  ConstructorStanding,
  DriverDetail,
  DriverFingerprintResponse,
  DriverStanding,
  Driver,
  FlagsResponse,
  LapTimesResponse,
  MiniSectorsResponse,
  PenaltiesResponse,
  PitStopsResponse,
  QualifyingSectorsResponse,
  RaceDriver,
  RaceReplay,
  RaceTraceMode,
  RaceTraceResponse,
  TyrePerformanceResponse,
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
  TitleScenariosResponse,
  WdcCalculator,
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
export const useResults = (year: number, rnd: number | null, session: string) =>
  useApi<SessionResults>(rnd != null ? `/api/results/${year}/${rnd}/${session}` : null);
export const useDriverStandings = (year: number) => useApi<DriverStanding[]>(`/api/standings/drivers/${year}`);
export const useConstructorStandings = (year: number) =>
  useApi<ConstructorStanding[]>(`/api/standings/constructors/${year}`);
export const useDrivers = (year: number) => useApi<Driver[]>(`/api/drivers/${year}`);
export const useWdcCalculator = (year: number, throughRound?: number | null) =>
  useApi<WdcCalculator>(`/api/wdc-calculator/${year}`, {
    through_round: throughRound ?? undefined,
  });

/**
 * Warms the WDC calculator cache for a historical round in the background.
 *
 * The backend shares one expensive per-season computation across every
 * `through_round` value, so a single warm-up call for any completed round is
 * enough to make the *entire* time-machine slider fast, not just that one
 * round: without this, the first scrub of a page visit pays for that shared
 * computation, which is what made dragging the slider feel janky until the
 * cache filled in. `preload` both kicks off the request and seeds SWR's
 * cache under the exact same key `useWdcCalculator` will look up, so if the
 * user's first scrub happens to land on this round, it resolves instantly.
 */
export function warmWdcCalculatorCache(year: number, throughRound: number) {
  void preload(buildPath(`/api/wdc-calculator/${year}`, { through_round: throughRound }), fetcher);
}
export const useDriverDetail = (year: number, driverId: string | null) =>
  useApi<DriverDetail>(driverId ? `/api/drivers/${year}/${driverId}` : null);
export const useTeams = (year: number) => useApi<Team[]>(`/api/teams/${year}`);
export const useTeamDetail = (year: number, teamId: string | null) =>
  useApi<Team>(teamId ? `/api/teams/${year}/${teamId}` : null);
export const useCircuits = (year: number) => useApi<Circuit[]>(`/api/circuits/${year}`);
export const useCircuitMap = (year: number, rnd: number | null) =>
  useApi<CircuitMap>(rnd != null ? `/api/circuit/${year}/${rnd}` : null);
export const useReplay = (year: number, rnd: number) => useApi<RaceReplay>(`/api/replay/${year}/${rnd}`);
export const useReplayPositions = (year: number, rnd: number) =>
  useApi<ReplayPositions>(`/api/replay-positions/${year}/${rnd}`);
export const useLapTimes = (year: number, rnd: number) => useApi<LapTimesResponse>(`/api/laptimes/${year}/${rnd}`);
export const useStrategy = (year: number, rnd: number) => useApi<StrategyResponse>(`/api/strategy/${year}/${rnd}`);
export const useWeather = (year: number, rnd: number | null, session: string) =>
  useApi<WeatherResponse>(rnd != null ? `/api/weather/${year}/${rnd}/${session}` : null);
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
export const usePenalties = (year: number, rnd: number, session = "R") =>
  useApi<PenaltiesResponse>(`/api/penalties/${year}/${rnd}`, { session });
export const useReliability = (year: number) => useApi<ReliabilityResponse>(`/api/reliability/${year}`);
export const useCompare = (year: number, d1: string | null, d2: string | null) =>
  useApi<CompareResponse>(d1 && d2 ? `/api/compare/${year}/${d1}/${d2}` : null);
export const useStandingsEvolution = (year: number) =>
  useApi<StandingsEvolutionResponse>(`/api/standings-evolution/${year}`);

// Derived analysis (analytics_service). Payloads arrive chart-ready: series are
// pre-sorted, colours resolved and axis domains supplied, so these hooks feed a
// chart directly rather than being reshaped here.
export const useRaceTrace = (year: number, rnd: number, mode: RaceTraceMode = "median") =>
  useApi<RaceTraceResponse>(`/api/race-trace/${year}/${rnd}`, { mode });
export const useTyrePerformance = (year: number, rnd: number) =>
  useApi<TyrePerformanceResponse>(`/api/tyre-performance/${year}/${rnd}`);
export const usePitStops = (year: number, rnd: number) =>
  useApi<PitStopsResponse>(`/api/pit-stops/${year}/${rnd}`);
export const useQualifyingSectors = (year: number, rnd: number) =>
  useApi<QualifyingSectorsResponse>(`/api/qualifying-sectors/${year}/${rnd}`);
export const useMiniSectors = (year: number, rnd: number, session = "Q", top = 10) =>
  useApi<MiniSectorsResponse>(`/api/minisectors/${year}/${rnd}`, { session, top });
export const useTitleScenarios = (
  year: number,
  d1?: string,
  d2?: string,
  throughRound?: number | null,
) =>
  useApi<TitleScenariosResponse>(`/api/title-scenarios/${year}`, {
    d1,
    d2,
    through_round: throughRound ?? undefined,
  });
export const useDriverFingerprint = (year: number, driverId: string | null) =>
  useApi<DriverFingerprintResponse>(driverId ? `/api/driver-fingerprint/${year}/${driverId}` : null);
