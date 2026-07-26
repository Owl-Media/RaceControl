// Response shapes for backend/fastf1_service.py, mirrored 1:1 for the web BFF.
// Field names match the backend's JSON output exactly (camelCase already).

export interface EventSession {
  name: string;
  date: string | null;
  identifier: string; // FP1, FP2, FP3, Q, S, SQ, SS, R
}

export interface ScheduleEvent {
  round: number;
  name: string;
  officialName: string | null;
  country: string | null;
  location: string | null;
  date: string | null;
  format: string | null;
  sessions: EventSession[];
  completed: boolean;
  year: number;
}

export interface ResultRow {
  position: number | null;
  classifiedPosition: string | null;
  driverNumber: string | null;
  abbreviation: string | null;
  driverId: string | null;
  firstName: string | null;
  lastName: string | null;
  fullName: string | null;
  headshotUrl: string | null;
  countryCode: string | null;
  teamName: string | null;
  teamId: string | null;
  teamColor: string | null;
  gridPosition: number | null;
  status: string | null;
  points: number | null;
  timeMs: number | null;
  q1: string | null;
  q2: string | null;
  q3: string | null;
}

export interface SessionResults {
  year: number;
  round: number;
  session: string;
  sessionName: string;
  eventName: string;
  totalLaps: number | null;
  results: ResultRow[];
}

export interface DriverStanding {
  position: number | null;
  points: number | null;
  wins: number | null;
  driverId: string;
  driverNumber: string | null;
  driverCode: string | null;
  givenName: string | null;
  familyName: string | null;
  nationality: string | null;
  dateOfBirth: string | null;
  teamName: string | null;
  teamId: string | null;
}

export interface ConstructorStanding {
  position: number | null;
  points: number | null;
  wins: number | null;
  teamId: string;
  teamName: string | null;
  nationality: string | null;
}

export interface Driver {
  driverId: string;
  givenName: string | null;
  familyName: string | null;
  code: string | null;
  number: string | null;
  nationality: string | null;
  dateOfBirth: string | null;
  teamName: string | null;
  teamId: string | null;
  teamColor: string | null;
  headshotUrl: string | null;
  countryCode: string | null;
  position: number | null;
  points: number | null;
  wins: number | null;
}

export interface DriverSeasonResult {
  round: number | null;
  raceName: string | null;
  position: number | null;
  points: number | null;
  grid: number | null;
  status: string | null;
}

export interface DriverDetail extends Driver {
  seasonResults: DriverSeasonResult[];
}

export interface TeamRosterEntry {
  driverId: string;
  name: string;
  code: string | null;
  number: string | null;
  headshotUrl: string | null;
}

export interface Team extends ConstructorStanding {
  teamColor: string | null;
  drivers: TeamRosterEntry[];
}

export interface Circuit {
  circuitId: string;
  name: string | null;
  locality: string | null;
  country: string | null;
  lat: number | null;
  long: number | null;
}

export interface CircuitMapPoint {
  x: number;
  y: number;
  z: number;
  speed: number;
  drs: number;
  distance: number;
}

export interface CircuitCorner {
  number: number;
  letter: string;
  x: number;
  y: number;
}

export interface CircuitMap {
  year: number;
  round: number;
  eventName: string | null;
  location: string | null;
  country: string | null;
  outline: { x: number; y: number }[];
  points: CircuitMapPoint[];
  corners: CircuitCorner[];
  rotation: number;
  lengthMeters: number | null;
  minElevation: number | null;
  maxElevation: number | null;
  fastestLap: {
    driver: string | null;
    driverName: string | null;
    team: string | null;
    teamColor: string | null;
    time: string | null;
    compound: string | null;
  } | null;
}

export interface ReplayEntry {
  position: number;
  driver: string;
  driverId: string | null;
  teamColor: string | null;
  teamName: string | null;
  lapTimeMs: number | null;
  lapTime: string | null;
  compound: string | null;
  tyreLife: number | null;
}

export interface ReplayFrame {
  lap: number;
  order: ReplayEntry[];
}

export interface RaceReplay {
  year: number;
  round: number;
  eventName: string | null;
  totalLaps: number;
  drivers: { code: string; driverId: string | null; fullName: string | null; teamName: string | null; teamColor: string | null; number: string | null }[];
  frames: ReplayFrame[];
}

export interface LapTimeEntry {
  lap: number;
  timeMs: number;
  compound: string | null;
}

export interface DriverLapTimes {
  code: string;
  driverId: string | null;
  teamName: string | null;
  teamColor: string | null;
  laps: LapTimeEntry[];
}

export interface LapTimesResponse {
  year: number;
  round: number;
  eventName: string;
  totalLaps: number;
  drivers: DriverLapTimes[];
}

export interface StrategyStint {
  stint: number;
  compound: string | null;
  startLap: number;
  endLap: number;
  laps: number;
}

export interface DriverStrategy {
  code: string;
  driverId: string | null;
  teamName: string | null;
  teamColor: string | null;
  pitStops: number;
  stints: StrategyStint[];
}

export interface StrategyResponse {
  year: number;
  round: number;
  eventName: string;
  totalLaps: number;
  drivers: DriverStrategy[];
}

export interface WeatherResponse {
  year: number;
  round: number;
  session: string;
  eventName: string | null;
  available: boolean;
  airTemp?: number | null;
  trackTemp?: number | null;
  humidity?: number | null;
  pressure?: number | null;
  windSpeed?: number | null;
  rainfall?: boolean;
  airTempMax?: number | null;
  trackTempMax?: number | null;
}

export interface RaceDriver {
  code: string;
  driverId: string | null;
  fullName: string | null;
  teamName: string | null;
  teamColor: string | null;
  number: string | null;
}

export interface TelemetryTrace {
  code: string;
  lapNumber: number | null;
  lapTime: string | null;
  lapTimeMs: number | null;
  compound: string | null;
  distance: number[];
  time: number[];
  speed: number[];
  throttle: number[];
  brake: number[];
  gear: number[];
  rpm: number[];
  drs: number[];
  x: number[];
  y: number[];
  driverName?: string | null;
  teamName?: string | null;
  teamColor?: string | null;
}

export interface TelemetryResponse {
  year: number;
  round: number;
  available: boolean;
  driver?: string;
  eventName?: string | null;
  trace?: TelemetryTrace;
}

export interface TelemetryCompareResponse {
  year: number;
  round: number;
  eventName: string | null;
  available: boolean;
  traces: TelemetryTrace[];
}

export interface Retirement {
  driver: string | null;
  fullName: string | null;
  driverId: string | null;
  teamName: string | null;
  teamColor: string | null;
  status: string;
  classifiedPosition: string | null;
}

export interface RetirementsResponse {
  year: number;
  round: number;
  eventName: string | null;
  retirements: Retirement[];
}

export interface ReliabilityEntry {
  driverId?: string;
  teamId?: string;
  name?: string;
  teamName?: string;
  finished: number;
  mechanical: number;
  accident: number;
  disqualified: number;
  other: number;
  dnf: number;
  starts: number;
  finishRate: number;
}

export interface ReliabilityResponse {
  year: number;
  races: number;
  drivers: ReliabilityEntry[];
  teams: ReliabilityEntry[];
}

export interface CompareRound {
  round: number | null;
  raceName: string | null;
  position: number | null;
}

export interface CompareDriver {
  driverId: string;
  name: string;
  teamName: string | null;
  points: number;
  wins: number;
  podiums: number;
  poles: number;
  bestFinish: number | null;
  dnf: number;
  raceWins_h2h: number;
  qualWins_h2h: number;
  rounds: CompareRound[];
}

export interface CompareResponse {
  year: number;
  drivers: [CompareDriver, CompareDriver];
}

export interface StandingsEvolutionPoint {
  round: number;
  points: number;
}

export interface StandingsEvolutionDriver {
  driverId: string;
  name: string;
  code: string | null;
  teamName: string | null;
  teamColor: string | null;
  points: number;
  series: StandingsEvolutionPoint[];
}

export interface StandingsEvolutionResponse {
  year: number;
  rounds: number[];
  drivers: StandingsEvolutionDriver[];
}

export interface FlagEvent {
  time: string | null;
  lap: number | null;
  category: string | null;
  flag: string | null;
  status: string | null;
  scope: string | null;
  sector: number | null;
  driverNumber: string | null;
  driverCode: string | null;
  message: string | null;
}

export type FlagPeriodType = "YELLOW" | "DOUBLE_YELLOW" | "RED" | "SC" | "VSC";

export interface FlagPeriod {
  type: FlagPeriodType;
  startLap: number;
  endLap: number;
  reason: string | null;
}

export interface FlagsResponse {
  year: number;
  round: number;
  session: string;
  eventName: string | null;
  totalLaps: number;
  events: FlagEvent[];
  periods: FlagPeriod[];
}

export type RaceControlCategory = "Flag" | "SafetyCar" | "Drs" | "CarEvent" | "Other";

export interface RaceControlMessage {
  time: string | null;
  lap: number | null;
  category: RaceControlCategory;
  flag: string | null;
  status: string | null;
  scope: string | null;
  sector: number | null;
  driverNumber: string | null;
  driverCode: string | null;
  message: string | null;
}

export interface RaceControlResponse {
  year: number;
  round: number;
  session: string;
  eventName: string | null;
  totalLaps: number | null;
  messages: RaceControlMessage[];
}
