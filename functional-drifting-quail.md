# RaceControl — Audit Findings & Signature Data Visualisation Programme

## Context

RaceControl is a four-part F1 analytics project: a FastAPI/FastF1 backend (`backend/`,
~5,700 LOC) serving 25 endpoints, plus three clients at near-full feature parity — iOS
(SwiftUI, 46 files), Android (Compose, 82 files) and Next.js web. The data model is now
locked, so this is the right moment to stop adding surface area and start extracting
insight from what's already there.

Two things prompted this work:

1. **The lap dataframe is barely mined.** The backend reads only 7 columns from
   FastF1's `session.laps` (`LapNumber`, `LapTime`, `Time`, `Driver`, `Compound`,
   `Position`, `TyreLife`). Sector times, speed traps, `PitInTime`/`PitOutTime`,
   `TrackStatus`, `IsPersonalBest`, `FreshTyre` and `IsAccurate` are all loaded into
   memory on every request and then discarded. Every visualisation below is powered by
   data the backend already pays to load.
2. **The current charts describe, they don't explain.** Lap Times, Strategy and
   Qualifying each pose an analytical question and then stop short of answering it. The
   nine visualisations here are the ones F1 analysts actually use — a race trace, a
   mini-sector dominance map, tyre degradation curves — and they are essentially absent
   from consumer F1 apps.

**Intended outcome:** nine new visualisations live on all three clients, powered by new
chart-ready backend endpoints, landing on a CI pipeline that actually runs their tests.

**Decisions taken** (confirmed with the user): build all nine visualisations; ship to
backend + iOS + Android + Web; remediate the high-severity audit findings *first*.

---

## Part 1 — Audit findings

### Severity: High

| # | Finding | Evidence |
|---|---|---|
| **A1** | **Backend CI runs 2 of 21 test files.** The workflow runs `pytest -v test_attest.py test_attest_endpoints.py`. The 19 service test files (~2,200 lines covering results, telemetry, strategy, flags, penalties, retirements, WDC, circuit map, replay positions) never execute. New endpoint tests would be dead on arrival. | [backend-ci.yml](.github/workflows/backend-ci.yml) |
| **A2** | **iOS has no test target.** `project.yml` declares one target, `type: application`. CI only does an unsigned simulator build. Logic that Android unit-tests in Kotlin (lap-time formatting, downsampling, flag-period containment, JSON string-or-number coercion) has no Swift counterpart. | [project.yml](RaceControlApp/project.yml), [ios-ci.yml](.github/workflows/ios-ci.yml) |
| **A3** | **Rate limiter buckets every user together.** `_rate_hits` keys on `request.client.host`. Uvicorn is started without `--proxy-headers`/`--forwarded-allow-ips`, so behind Coolify's proxy that value is the *proxy's* IP for every request. The 120/min limit is therefore a single global throttle: one abusive client 429s the entire user base, and it provides no per-abuser protection. | [main.py:147](backend/main.py:147), [Dockerfile](backend/Dockerfile), [run.sh](backend/run.sh) |

### Severity: Medium

| # | Finding | Evidence |
|---|---|---|
| **A4** | **Response cache is unbounded.** `cached()` writes `_CACHE[key] = (now, value)` and never evicts; the TTL is only consulted on read, so a stale entry is retained forever if never re-requested. Keys multiply across year × round × session × driver. `_SESSION_CACHE` correctly caps at 48 (`SESSION_CACHE_MAX`) — the response cache has no equivalent, on a container the README says to give 1–2 GB. | [main.py:166](backend/main.py:166) |
| **A5** | **Rate-limit map is unbounded.** `_rate_hits` accumulates one list per client key and is only pruned for clients that make a *new* request. Absent clients are never collected. (Largely masked today by A3 collapsing all traffic onto one key — fixing A3 exposes this.) | [main.py:147](backend/main.py:147) |
| **A6** | **`get_weather` bypasses the session cache.** It calls `fastf1.get_session(...)` and `session.load(weather=True)` directly rather than `_load_session`, so every weather request re-loads a session from scratch with no reuse. It then collapses the full `weather_data` time series to means and one `rainfall` boolean, discarding the series. | [fastf1_service.py:1671](backend/fastf1_service.py:1671) |
| **A7** | **Android has never been compiled.** `docs/TASKS.md` states this outright: the version catalogue was pinned without a dependency resolver, and Phase 10 reads "**no compile yet**". CI (`assembleDebug`) would surface it. | [TASKS.md](RaceControlAndroid/docs/TASKS.md) |
| **A8** | **No Web CI and no web tests.** Workflows exist for android, backend and iOS only. No `*.test.*`/`*.spec.*` anywhere in `RaceControlWeb`, despite it hosting non-trivial derivation logic (`lib/trackGeometry.ts`, `lib/replay.ts`, `lib/format.ts`). | [.github/workflows](.github/workflows) |

### Severity: Low

| # | Finding | Evidence |
|---|---|---|
| **A9** | **Chart-library doc drift.** `TASKS.md` 1.3 and `FEATURES.md` §3.8 specify Vico for Android line/bar charts. No Vico dependency exists; charts are hand-rolled Compose Canvas in `RcCharts.kt`. The implementation is the *better* call (it keeps Android visually identical to iOS/Web and `RcCharts.kt`'s own header explains the reasoning) — the docs should be corrected to match, not the code. | [RcCharts.kt](RaceControlAndroid/app/src/main/java/com/owlmedia/racecontrol/core/ui/RcCharts.kt), [FEATURES.md](RaceControlAndroid/docs/FEATURES.md) |
| **A10** | **Unmined lap columns** — see Context. Not a defect; it is the entire opportunity this plan exploits. | [fastf1_service.py](backend/fastf1_service.py) |

### The governing architectural finding

**D1 — three independent chart stacks.** iOS uses Swift Charts, Android uses hand-rolled
Compose `Canvas` (`RcCharts.kt`), Web uses Recharts. Every visualisation is therefore
three implementations. A nine-visualisation programme is only tractable if **all
derivation happens once, in the backend**, and each endpoint returns a *chart-ready*
payload — pre-binned, pre-sorted, team colours resolved, axis domains supplied — so each
client does nothing but map a prepared series onto a primitive it already has.

This principle governs every endpoint below and is the main reason the plan is shaped
around backend work first.

---

## Part 2 — Phase 0: high-severity remediation

Land before any new endpoint, so new tests actually run.

- **A1** — `backend-ci.yml`: replace the two-file invocation with `python -m pytest -v`
  (collects all 21 files). Expect some currently-unrun tests to fail; fix or explicitly
  `-k`-exclude with a comment naming why. This is the gate for everything after it.
- **A2** — Add a `RaceControlTests` unit-test target to `project.yml`
  (`type: bundle.unit-test`), add a `test` step to `ios-ci.yml`, and port the four
  Kotlin unit tests that cover shared logic (`LapTimeFormatTest`, `DownsampleTest`,
  `FlagPeriodTest`, `JsonValueTest`) to Swift as the seed suite.
- **A3** — Add `--proxy-headers --forwarded-allow-ips="*"` to the `Dockerfile` CMD, and
  key the limiter off the leftmost `X-Forwarded-For` entry with `request.client.host` as
  fallback. Extract as `_client_key(request)` so it is unit-testable, and add a test
  asserting two different `X-Forwarded-For` values get independent buckets.
- **A4 / A5** — Give `_CACHE` an LRU bound (`CACHE_MAX_ENTRIES`, default ~256) mirroring
  the existing `_SESSION_CACHE`/`_SESSION_ORDER` pattern, and sweep `_rate_hits` of
  empty/expired client entries on write.

Deferred to a follow-up (not blocking): **A6**, **A7**, **A8**, **A9**. A6 is folded
into Phase 3 below, since the weather timeline needs that code path anyway.

---

## Part 3 — The nine visualisations

### Shared backend spine

Create **`backend/analytics_service.py`** rather than growing `fastf1_service.py`
(already 2,256 lines). It imports and reuses, without reimplementing:

| Helper | File | Use |
|---|---|---|
| `_load_session` | `fastf1_service.py:246` | cached session loads (respect `with_telemetry`) |
| `_driver_meta` | `fastf1_service.py:1247` | driver names, numbers, team colours |
| `_td_ms`, `_fmt_lap`, `_clean`, `_clean_utc` | `fastf1_service.py` | ms/timedelta/string normalisation |
| `_flag_periods`, `_race_control_rows` | `fastf1_service.py:1618`, `:1403` | SC/VSC/yellow bands for overlays |
| `_genuine_position_samples` | `fastf1_service.py` | position-channel dedup (mini-sector map) |
| `_pick_outline_lap` | `fastf1_service.py:850` | track outline selection |
| `_is_finish_status`, `_retirement_display_status` | `fastf1_service.py:1908` | consistent retirement semantics |
| `_points_progression` | `fastf1_service.py:2149` | memoised cumulative points (title matrix) |
| `cached`, `_guard` | `main.py:166`, `:176` | 6h response cache + 502 normalisation |

Every new route in `main.py` follows the existing one-liner shape:
`cached(key, lambda: _guard(lambda: analytics.get_x(...), "x"))`.

Each payload carries `available: bool` and an empty-but-valid body on missing data, so
clients reuse their existing empty/error states rather than special-casing.

### Client primitives to reuse

- **iOS** — Swift Charts (`LineMark`, `AreaMark`, `PointMark`, `BarMark`, `RectangleMark`,
  `RuleMark`, `.chartOverlay`), `TrackMapRich.swift` `Canvas`, `Theme.Palette`,
  `TyreCompound`, `FlagStyle`, `LoadableView`. New tiles slot into the existing
  `RaceAnalysisGrid.swift` `tile(...)` pattern.
- **Android** — `RcCharts.kt`: `RcLineChart`, `ChartSeries`, `ChartPoint`, `ChartBand`,
  `ChartDomain.cover`, `Sparkline`, `StackedBar`/`BarSegment`; `TrackMap.kt`;
  `RcPalette`, `TyreCompound`, `FlagStyle`; `UiState`/`StateViews`.
- **Web** — Recharts (`LineChart`, `ScatterChart`, `BarChart`, `RadarChart`,
  `ReferenceArea`), `TrackMap.tsx`, `MiniTrackMap.tsx`, `lib/api.ts` SWR hooks,
  `StateViews`, `lib/tyres.ts`, `lib/flags.ts`.

**New primitives needed** (added to `RcCharts.kt` on Android, native elsewhere):
`RcScatterChart`, `RcWaterfallBars`, `RcHeatmapGrid`, `RcRadar`. Swift Charts and
Recharts cover all four natively except the radar on iOS (one `Canvas`).

---

### Phase 1 — Race-story trio *(highest value per hour)*

#### V1. Race Trace — `GET /api/race-trace/{year}/{rnd}?mode=median|leader`

The single most informative chart in F1 analysis, and the flagship of this programme.
X = lap, Y = cumulative time delta, one team-coloured line per driver.

- `mode=median` (default): `trace[d][n] = cumulative_time[d][n] − n × reference_lap`,
  where `reference_lap` is the median green-flag lap of the race. De-trending the field
  flattens the lines and makes **vertical distance between any two lines equal the real
  gap in seconds** — that property is what makes the chart readable.
- `mode=leader`: delta to whoever holds `Position == 1` at that lap.

Data: `laps.Time` (session time at lap end) + `LapNumber` + `Position`. Handle lapped
cars, retirements (series simply terminates), and non-starters. Return `periods` from
`_flag_periods` alongside, so clients band safety-car stretches — the exact pattern
`LapTimesTab.tsx` and `LapTimesChartView.swift` already use.

Clients: multi-series line + bands. iOS `LineMark`+`RectangleMark`; Android `RcLineChart`
with `bands`; Web Recharts `LineChart`+`ReferenceArea`. Default to the top 5 finishers
with driver chips to adjust, following the existing "first 3 shown" convention in
`LapTimesTab.tsx`.

#### V2. Position Bump Chart — **no new backend work**

X = lap, Y = position (1 at top), team-coloured lines, SC/VSC bands, pit-stop markers,
retirement terminators. `/api/replay` already returns per-lap `position` for every
driver plus `compound` and `lapTimeMs`; `/api/strategy` supplies stint boundaries for the
pit markers. Pure client work — the cheapest striking visual in the set.

#### V3. Tyre Degradation Curves — `GET /api/tyre-performance/{year}/{rnd}`

X = tyre life (laps on that set), Y = lap-time delta to the driver's own stint best.
One trace per stint, coloured by compound, each with a fitted linear degradation slope
(s/lap) reported numerically — that slope is the answer the current Strategy screen
implies but never gives.

Data: `Compound`, `TyreLife`, `FreshTyre`, `LapTime`, and critically `TrackStatus` +
`IsAccurate` to **exclude safety-car, in/out and deleted laps**, which would otherwise
swamp the trend. Also return a per-compound field-wide baseline slope for comparison.

Clients: scatter + fitted line. New `RcScatterChart` on Android; `PointMark`+`LineMark`
on iOS; Recharts `ScatterChart` on Web.

### Phase 2 — Unused-column set

#### V4. Pit-Stop / Undercut Ledger — `GET /api/pit-stops/{year}/{rnd}`

Real pit-lane time loss per stop from `PitInTime`/`PitOutTime` — not a stint-count proxy.
Dumbbell per stop: time lost, position entering vs rejoining, and the undercut/overcut
outcome inferred by comparing against rivals' laps in the same window. Include a
per-circuit median loss so a slow stop is visibly slow.

Clients: horizontal dumbbell/bar rows — `BarMark` (iOS), extended `StackedBar` (Android),
Recharts `BarChart` (Web).

#### V5. Qualifying Sector Waterfall — `GET /api/qualifying-sectors/{year}/{rnd}`

Gap-to-pole decomposed into S1/S2/S3 per driver as a stacked waterfall, with negative
segments where a driver *beat* pole in that sector, plus a **theoretical ideal lap** row
(each driver's best S1+S2+S3 across all their laps in the session) and `SpeedST` trap
speeds. Turns the existing Qualifying screen from a table into an analysis.

Data: `Sector1Time`/`Sector2Time`/`Sector3Time`, `SpeedI1`/`SpeedI2`/`SpeedFL`/`SpeedST`,
`IsPersonalBest`, `Deleted` — all currently unread. Extends `get_results`' existing
`q1/q2/q3` + gap shape rather than replacing it.

### Phase 3 — Mini-sector dominance *(the signature visual)*

#### V6. Mini-Sector Dominance Map — `GET /api/minisectors/{year}/{rnd}?session=Q&top=10`

The track outline redrawn as ~24 distance-binned segments, each taking the team colour of
whoever was fastest through it on their fastest lap. The most recognisable visual in F1
analysis and, as far as the audit found, absent from every consumer F1 app.

Implementation: for each driver in scope, take their fastest lap's telemetry (the same
`_lap_telemetry` path already used by `/api/telemetry`), bin by `Distance` into N
mini-sectors, compute each driver's time through each bin, and emit per-segment
`{index, startDistance, endDistance, points: [[x,y]…], winnerCode, teamColor, gapMs}`.
Reuse `_genuine_position_samples` so segments curve rather than corner.

**Cost risk — flagged explicitly.** This needs telemetry for N drivers in one request.
`get_replay_positions` already hit exactly this wall (its docstring records blowing past
reverse-proxy timeouts). Mitigations, all required:
- Cap drivers via `?top=` (default 10) plus a `MINISECTOR_MAX_DRIVERS` env ceiling.
- Prefer `session=Q` as the default — one clean flying lap per driver, far cheaper and
  more meaningful than race laps.
- Derive server-side and return only ~24 segments of ~15 points each, so the payload is
  tiny regardless.
- Rely on the 6h `cached()` TTL; document that the cold-cache first request is slow.
- Verify a cold request completes inside the deployed proxy's timeout before shipping.

Also fold in **A6** here: route `get_weather` through `_load_session` and expose the
`weather_data` time series it currently discards, giving a banded weather timeline
(track/air temp, rainfall) that overlays the lap-time and race-trace charts.

Clients: colour an existing polyline. `TrackMapRich.swift`, `TrackMap.kt`, `TrackMap.tsx`
all already draw the outline — this changes the stroke, not the geometry.

### Phase 4 — Season-level pair

#### V7. Title Permutation Matrix — `GET /api/title-scenarios/{year}?d1=&d2=`

Extends the existing WDC calculator from "can they win" to "what has to happen". A grid
of leader-finish × rival-finish permutations over the remaining rounds, each cell
coloured by title outcome, plus generated clinch text ("Norris takes it with P3 or
better in Abu Dhabi"). Built entirely on `_points_progression` and `get_wdc_calculator`
— no new data source, and it slots behind the `WdcBadge`/`TitleDeciderScreen` entry
points that already exist on Android and Web.

Clients: heatmap grid — `RectangleMark` (iOS), new `RcHeatmapGrid` (Android), CSS grid
(Web).

#### V8. Driver Season Fingerprint — `GET /api/driver-fingerprint/{year}/{driver_id}`

A six-axis percentile radar: quali pace vs teammate, race pace, tyre management (V3's
degradation slope), start performance (grid → lap-1 delta), reliability (from
`get_reliability`), and wet-weather pace (from the weather series). Every input derives
from data already exposed or from the columns Phase 2 unlocks. The most shareable artifact
in the set, and it gives the Drivers tab a reason to be revisited.

Clients: radar — `Canvas` (iOS), new `RcRadar` (Android), Recharts `RadarChart` (Web).

#### V9. Weather Timeline

Ships as part of the A6 fix in Phase 3; listed here for completeness as the ninth
visualisation.

---

## Part 4 — Verification

**Backend** — for each new endpoint, a `test_*_service.py` alongside the existing 19,
following their established style (they are the pattern to copy). Cover: the empty/no-data
path returns `available: false` rather than raising; SC/in/out/deleted-lap exclusion in V3;
sector arithmetic and ideal-lap construction in V5; mini-sector binning boundaries in V6;
permutation correctness in V7. Then:

```bash
cd backend && python -m pytest -v
```

Confirm the count jumps from the 2 files CI runs today to all 21 plus the new ones.

**Live smoke test** against a real season — a race with a red flag and a wet session
exercises the edge cases best (2021 Belgium, 2023 Australia):

```bash
cd backend && ./run.sh
```

Then check payload shape and cold-cache latency per endpoint, e.g.:

```bash
curl -s "http://localhost:8000/api/race-trace/2023/1?mode=median" | head -c 2000
```

Time the mini-sector endpoint cold specifically — it is the one with a real timeout risk:

```bash
time curl -s -o /dev/null "http://localhost:8000/api/minisectors/2023/1?session=Q&top=10"
```

**iOS** — build and run in the simulator, open each new analysis tile, verify against the
backend JSON. The `run` skill covers launching; the iOS Simulator tools can screenshot each
new chart for review.

**Android** — `./gradlew testDebugUnitTest assembleDebug`. Note **A7**: this will be the
project's first Android compile, so expect version-catalogue reconciliation before any new
code is judged.

**Web** — `npm run dev`, walk each new tab, and confirm light/dark plus mobile widths.

**Cross-platform parity** — for one chosen race, diff the same visualisation across all
three clients. The repo's convention is three-way parity, and these charts are derived
data, so any divergence means a client is deriving something the backend should have.

## Risks

- **V6 cold-request latency** is the main delivery risk; the mitigations above are
  requirements, not options. If a cold request cannot fit the proxy timeout, fall back to
  a precompute-on-write path rather than raising the timeout.
- **Phase 0 A1 may surface pre-existing failures** in the 19 never-run test files. That is
  the finding working as intended, but it could absorb time before feature work starts.
- **Nine visualisations × four codebases is a large programme.** Phases are ordered by
  value-per-hour (V2 needs no backend work at all), so it is safe to stop after any phase
  with a coherent result.
