# RaceControl plan task list

Source: [`functional-drifting-quail.md`](functional-drifting-quail.md)

## Phase 0 — High-severity remediation

- [x] A1 — Run the complete backend pytest suite in CI.
- [x] A2 — Add the iOS unit-test target and CI test action.
  - [x] Lap-time formatting tests.
  - [x] `JSONValue` decoding tests.
  - [x] Flag-period interpretation tests.
  - [x] Downsampling tests.
- [x] A3 — Resolve rate-limit clients correctly behind a trusted proxy.
- [x] A4 — Make response-cache recency tracking bounded and truly LRU.
- [x] A5 — Sweep stale rate-limit entries on every write.
- [x] A6 — Route weather through the shared session cache and return its timeline (Phase 3).
- [x] A7 — Complete the first Android unit-test and debug-assembly verification.

## Phase 1 — Race-story trio

- [x] V1 — Race trace.
  - [x] Backend `/api/race-trace/{year}/{round}` endpoint.
  - [x] Fixed green-flag reference-lap and leader modes.
  - [x] Flag-period overlays and chart-ready domains.
  - [x] Backend arithmetic and empty-state tests.
  - [x] iOS, Android, and web views.
- [x] V2 — Position bump chart.
  - [x] Replay and strategy data composition.
  - [x] Top-five default driver selection.
  - [x] Flag bands, pit markers, and retirement terminators.
  - [x] iOS, Android, and web views.
- [x] V3 — Tyre degradation curves.
  - [x] Backend `/api/tyre-performance/{year}/{round}` endpoint.
  - [x] Exclude neutralised, inaccurate, deleted, in-lap, and out-lap samples.
  - [x] Per-stint fitted slope and field-wide compound baselines.
  - [x] Backend exclusion and arithmetic tests.
  - [x] iOS, Android, and web views.
  - [x] Android point/scatter support in the shared chart primitive.

## Phase 2 — Unused-column set

- [x] V4 — Pit-stop / undercut ledger.
  - [x] Backend `/api/pit-stops/{year}/{round}` endpoint.
  - [x] Real pit-lane loss, entry/rejoin positions, rival-window outcome, circuit median.
  - [x] Backend empty-state and arithmetic tests.
  - [x] iOS, Android, and web views.
- [x] V5 — Qualifying sector waterfall.
  - [x] Backend `/api/qualifying-sectors/{year}/{round}` endpoint.
  - [x] Sector gap decomposition, negative segments, ideal laps, and speed traps.
  - [x] Backend sector and ideal-lap tests.
  - [x] iOS, Android, and web views.
  - [x] Android waterfall primitive.

## Phase 3 — Signature visuals and weather

- [x] V6 — Mini-sector dominance map.
  - [x] Backend `/api/minisectors/{year}/{round}` endpoint.
  - [x] Driver cap, environment ceiling, approximately 24 bins, curved sampled geometry.
  - [x] Backend bin-boundary tests.
  - [x] iOS, Android, and web map views.
  - [x] Local cold-cache request: 3.85 seconds for 2025 Australia qualifying, top 10.
  - [ ] Verify cold-cache latency against the deployed proxy timeout.
- [x] A6 / V9 — Cached weather timeline.
  - [x] Route weather loading through `_load_session`.
  - [x] Return the full weather series.
  - [x] Add timeline overlays to relevant clients.

## Phase 4 — Season-level pair

- [x] V7 — Title permutation matrix.
  - [x] Backend `/api/title-scenarios/{year}` endpoint.
  - [x] Permutation tests and clinch-text generation.
  - [x] iOS, Android, and web heatmaps.
  - [x] Android heatmap primitive.
- [x] V8 — Driver season fingerprint.
  - [x] Backend `/api/driver-fingerprint/{year}/{driver_id}` endpoint.
  - [x] Six percentile axes sourced from the shared analytics.
  - [x] iOS, Android, and web radar views.
  - [x] Native radar primitives where required.

## Verification

- [x] Phase 0/1 targeted backend tests: 44 passed.
- [x] Phase 2–4 targeted backend tests: 17 passed.
- [x] Complete backend suite exercised locally: 145 passed; two Apple-attestation tests are blocked by the local Python 3.14/macOS `oscrypto` trust-store failure. CI runs Python 3.12 on Ubuntu.
- [x] iOS unit suite: 43 passed.
- [x] iOS simulator test action succeeded after all phases.
- [x] Android `testDebugUnitTest assembleDebug` succeeded.
- [x] Web ESLint succeeded.
- [x] Web TypeScript typecheck succeeded.
- [x] Web production build succeeded in a network-enabled environment.
- [x] Live backend JSON smoke tests against wet 2025 Australia and red-flag 2023 Australia.
- [ ] Cross-platform visual parity review using one shared race.
