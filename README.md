# RaceControl 🏁

A modern, native **iOS app** for exploring historical Formula 1 data — drivers, teams,
circuits, standings, full session results, and a **lap-by-lap race replay** — powered by
the [FastF1](https://docs.fastf1.dev) library (2018–present).

RaceControl is two pieces:

| Piece | Tech | Folder |
|------|------|--------|
| **iOS app** | Swift · SwiftUI (iOS 17+) | [`RaceControlApp/`](RaceControlApp/) |
| **Data backend** | Python · FastAPI · FastF1 | [`backend/`](backend/) |

FastF1 is a Python library (not a hosted web service), so the backend runs FastF1 on your
machine and exposes clean JSON over REST; the SwiftUI app consumes it. A native Android
client also lives in [`RaceControlAndroid/`](RaceControlAndroid/), against the same backend.

[![Backend CI](https://github.com/Owl-Media/RaceControl/actions/workflows/backend-ci.yml/badge.svg)](https://github.com/Owl-Media/RaceControl/actions/workflows/backend-ci.yml)
[![Android CI](https://github.com/Owl-Media/RaceControl/actions/workflows/android-ci.yml/badge.svg)](https://github.com/Owl-Media/RaceControl/actions/workflows/android-ci.yml)
[![iOS CI](https://github.com/Owl-Media/RaceControl/actions/workflows/ios-ci.yml/badge.svg)](https://github.com/Owl-Media/RaceControl/actions/workflows/ios-ci.yml)

### Continuous integration

Three independent GitHub Actions workflows in [`.github/workflows/`](.github/workflows/),
each path-filtered so a change to one piece doesn't run the others' checks:

| Workflow | Runs on changes to | What it does |
|---|---|---|
| `backend-ci.yml` | `backend/**` | Installs `requirements.txt` + `pytest`/`httpx`, runs `test_attest.py` and `test_attest_endpoints.py`, then imports `main.py` with no env vars to confirm the open-by-default local-dev path still boots. |
| `android-ci.yml` | `RaceControlAndroid/**` | `./gradlew testDebugUnitTest` then `./gradlew assembleDebug`; uploads the test reports as a build artifact. |
| `ios-ci.yml` | `RaceControlApp/**` | Unsigned `xcodebuild build` against `generic/platform=iOS Simulator`, on a macOS runner. |

This is CI only — nothing here deploys anywhere. Deploying the backend to Coolify is still
the manual process in section 1b below; there's no Play Store or TestFlight upload wired up
(those would need a Play Console service-account key and Apple signing certs as repo
secrets, which haven't been set up).

---

## 1. Run the backend

Requirements: Python 3.10+.

```bash
cd backend
./run.sh            # creates a venv, installs deps, starts the API
```

The API starts on **http://localhost:8000**. Open **http://localhost:8000/docs** for the
interactive Swagger UI. The first request for a given race downloads and caches its data
(FastF1 caches to `backend/.fastf1_cache/`), so it's slow once and fast thereafter.

Manual start (instead of `run.sh`):

```bash
cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/seasons` | Available seasons (2018–present) |
| GET | `/api/schedule/{year}` | Race calendar for a season |
| GET | `/api/results/{year}/{round}/{session}` | Classification (`R`, `Q`, `S`, `FP1`…) |
| GET | `/api/standings/drivers/{year}` | Driver championship standings |
| GET | `/api/standings/constructors/{year}` | Constructor standings |
| GET | `/api/drivers/{year}` | Season drivers (headshots, teams, points) |
| GET | `/api/drivers/{year}/{driverId}` | Driver detail + per-round results |
| GET | `/api/teams/{year}` | Constructors with rosters & colours |
| GET | `/api/teams/{year}/{teamId}` | Team detail |
| GET | `/api/circuits/{year}` | Circuits visited that season |
| GET | `/api/circuit/{year}/{round}` | Track outline + corners, length & fastest lap |
| GET | `/api/replay/{year}/{round}` | **Lap-by-lap running order** for the replay |
| GET | `/api/laptimes/{year}/{round}` | Per-driver lap-time series (evolution chart) |
| GET | `/api/strategy/{year}/{round}` | Tyre stints & pit-stop counts per driver |
| GET | `/api/weather/{year}/{round}/{session}` | Session weather summary |
| GET | `/api/telemetry/{year}/{round}/{driver}` | Fastest-lap telemetry trace |
| GET | `/api/telemetry-compare/{year}/{round}?d1=&d2=` | Two-driver telemetry overlay |
| GET | `/api/racedrivers/{year}/{round}` | Driver list for a race (pickers) |
| GET | `/api/retirements/{year}/{round}` | Non-finishers with cause |
| GET | `/api/reliability/{year}` | Season DNF breakdown per driver/team |
| GET | `/api/compare/{year}/{d1}/{d2}` | Two-driver season head-to-head |

---

## 1b. Deploy the backend to Coolify

The backend ships with a `Dockerfile`, so Coolify can build and run it directly.
Local development is unaffected — `./run.sh` still runs it natively with no auth.

### Create the app in Coolify

1. **New Resource → Application → Public/Private Repository**, point it at this repo.
2. **Build Pack:** `Dockerfile`. **Base Directory:** `/backend`.
3. **Port:** `8000` (the container also honours `$PORT` if Coolify overrides it).
4. **Health check path:** `/api/health` — deliberately left unauthenticated so the
   platform can probe it.

### Environment variables

| Variable | Value | Notes |
|---|---|---|
| `APP_ATTEST_ENABLED` | `true` | Gate the API with Apple App Attest (see below). |
| `APPLE_TEAM_ID` | your 10-char Team ID | From developer.apple.com. |
| `APP_BUNDLE_ID` | `com.codenameowl.racecontrol` | Must match the app's bundle id. |
| `APP_ATTEST_PRODUCTION` | `false` dev / `true` release | Must match the app's entitlement environment. |
| `JWT_SECRET` | `openssl rand -hex 32` | Signs the short-lived app tokens. |
| `API_TOKEN` | `openssl rand -hex 32` | Optional admin/break-glass secret. |
| `RATE_LIMIT_PER_MINUTE` | `120` | Per-IP limit; `0` disables. |
| `FASTF1_CACHE` | `/data/fastf1_cache` | Already the image default. |
| `WEB_CONCURRENCY` | `1` | Each worker holds its own cache — raise only with more RAM. |
| `SESSION_CACHE_MAX` | `24` | Lower than the default 48 on a small container. |
| `CACHE_TTL_SECONDS` | `21600` | Response cache lifetime (6 hours). |

See [`backend/.env.example`](backend/.env.example) for the full list. If you set
**neither** `APP_ATTEST_ENABLED` nor `API_TOKEN`, the API is open (local dev only).

### Persistent storage (important)

Add a **persistent volume mounted at `/data`**. FastF1 caches every session it
downloads there; without it each redeploy re-downloads everything, which is slow
and burns through the upstream F1/Jolpica rate limits. Budget a few GB if you
plan to browse a lot of telemetry.

### Resources

Loading a race session with telemetry is pandas-heavy. Give the container
**at least 1 GB RAM (2 GB recommended)**. If it gets OOM-killed while loading
telemetry, lower `SESSION_CACHE_MAX` first.

### Point the app at it

In the app: **gear icon → Backend Server** = your Coolify HTTPS URL, and
**API Token** = the same `API_TOKEN` value. Tap **Test Connection** — it checks
reachability *and* validates the token. The token is stored in the device
Keychain, not UserDefaults.

> The app's ATS policy allows cleartext HTTP only to `localhost`/LAN addresses,
> so a deployed backend must be HTTPS. Coolify handles the certificate for you.

---

## 1c. App Store distribution — App Attest (no user API keys)

A shared `API_TOKEN` can't ship in a public app — anything bundled in the IPA
can be extracted, so it wouldn't be secret. Instead, the published app uses
**Apple App Attest**: each install proves, with a hardware-backed key attested
by Apple, that requests come from a genuine, unmodified copy of *this* app on a
real Apple device. No user-visible key, nothing to distribute.

### How it works

```
App                                    Backend
 │  GET /attest/challenge  ──────────▶  issues a one-time nonce
 │  DCAppAttestService.attestKey       verify cert chain → Apple root,
 │  POST /attest/verify    ──────────▶  nonce, app id, key id  → returns JWT
 │  GET /api/...  (Bearer <JWT>) ─────▶  normal requests
 │  (JWT expires)
 │  generateAssertion + POST           verify signature + counter (replay
 │  /attest/token         ──────────▶  protection) → returns fresh JWT
```

The app caches the JWT in the Keychain and refreshes it with a cheap assertion;
it only re-attests if the server forgets its key. All of this is automatic and
invisible to the user — there's no key field for them to fill in.

### Backend setup

1. Set `APP_ATTEST_ENABLED=true`, `APPLE_TEAM_ID`, `APP_BUNDLE_ID`, `JWT_SECRET`.
2. Match environments: Xcode debug builds use the **development** App Attest
   environment (`APP_ATTEST_PRODUCTION=false`); TestFlight/App Store use
   **production** (`APP_ATTEST_PRODUCTION=true`). A mismatch = every attestation
   is rejected.
3. Attested keys are persisted to `ATTEST_DB` (defaults under `/data`), so keep
   the persistent volume — otherwise every redeploy forces all installs to
   re-attest (harmless, just an extra round-trip on next launch).

### iOS setup (Xcode)

1. The **App Attest capability** is already wired: `RaceControl.entitlements`
   contains `com.apple.developer.devicecheck.appattest-environment` and the
   project references it via `CODE_SIGN_ENTITLEMENTS`. In **Signing &
   Capabilities**, confirm "App Attest" is listed (add it if your team needs to
   register the capability).
2. Set the `development`/`production` value in the entitlement to match the
   backend for the build you're shipping.
3. Use a real device — **App Attest does not work in the Simulator.** There, the
   app falls back to the admin token (Settings) or an open local server.

### What this does and doesn't protect

- ✅ Strongly binds API access to genuine installs of your app on real Apple
  devices, plus per-IP rate limiting as defence in depth.
- ⚠️ It is not a login — there are no user accounts (the data is public F1
  history). It stops abuse/scraping, not "authenticated users".
- ⚠️ **The server-side verification could not be tested end-to-end here** (that
  needs a real device + your developer account). The verification *logic* is
  covered by offline tests — `python backend/test_attest.py` and
  `python backend/test_attest_endpoints.py` — using Apple's documented steps via
  the `pyattest` library. Do a real-device smoke test before shipping.

---

## 2. Run the iOS app

Requirements: **Xcode 16+**, macOS.

1. Open `RaceControlApp/RaceControl.xcodeproj` in Xcode.
2. Select an iPhone simulator (e.g. iPhone 15 Pro) and press **⌘R**.
3. The app defaults to `http://localhost:8000`, which the simulator can reach on your Mac.

**Testing on a physical iPhone?** Your phone can't see `localhost`. In the app, tap the
**gear icon** (top-left of the Races tab) → **Backend Server**, and enter your Mac's LAN
address, e.g. `http://192.168.1.20:8000` (find it with `ipconfig getifaddr en0`). Tap
**Test Connection**, then **Save**. Your Mac and iPhone must be on the same Wi-Fi.

> The bundled `Info.plist` allows plain-HTTP for local development. For a production build,
> serve the API over HTTPS and remove `NSAllowsArbitraryLoads`.

### Regenerating the Xcode project (optional)

The project uses Xcode 16's synchronized file groups, so new Swift files added to
`RaceControlApp/RaceControl/` are picked up automatically — no project edits needed. If you
ever need to rebuild the project file from scratch, an [XcodeGen](https://github.com/yonaskolb/XcodeGen)
spec is provided:

```bash
cd RaceControlApp
brew install xcodegen && xcodegen generate
```

---

## 3. Features

- **Races** — season calendar with an "up next" banner, sprint-weekend badges, and per-race
  results. Switch between Race / Qualifying / Sprint / Practice classifications. Each row
  shows gap-to-leader, grid delta (places gained/lost) and points.
- **Race Replay** — scrub or play through a race lap by lap and watch the running order
  animate, with position-change arrows, tyre compounds and lap times. Adjustable 0.5×–4× speed.
- **Drivers** — searchable roster with headshots, numbers and team colours; driver detail
  with a season form sparkline and every result.
- **Constructors** — standings-ordered team cards with driver line-ups and team liveries.
- **Standings** — driver & constructor championships with gap-to-leader bars and win counts.
- **Circuits** — season venues in calendar order with Raced/Upcoming status; tap a raced one
  for a detail page: **track map**, length, corners, fastest lap, podium, and quick actions.
- **Race analysis hub** — every completed race opens a grid of deep-dives:
  - **Telemetry** — speed / throttle / gear traces over a lap (Swift Charts), with an optional
    second driver overlaid for a head-to-head comparison.
  - **Lap Times** — multi-driver lap-time evolution line chart with outlier filtering.
  - **Tyre Strategy** — stint timeline per driver with compound colours and pit counts.
  - **Qualifying** — Q1/Q2/Q3 breakdown with gap-to-pole.
  - **Weather** — air/track temps, humidity, wind, rainfall.
  - **Retirements** — non-finishers categorised by cause (mechanical / accident / DSQ).
- **Reliability** (Standings tab) — season finish-rate and DNF-by-cause bars per driver & team.
- **Head-to-head** (Drivers tab) — pick two drivers and compare points, wins, podiums, poles,
  best finish, DNFs and their direct race/qualifying records.

## 4. Design notes

Built against Apple's Human Interface Guidelines and mobile-design best practices:
dark-first OLED-tuned palette, official F1 team/tyre colours, 44pt+ touch targets,
Dynamic Type, semantic SF Symbols, tab-bar navigation (≤5 tabs), and consistent
loading / error-with-retry / empty states on every screen.

## 5. Architecture

```
SwiftUI app  ──HTTP/JSON──▶  FastAPI  ──▶  FastF1 ──▶ F1 live-timing + Ergast/Jolpica
   MVVM                       cache            disk cache
```

- **App:** MVVM. Each feature has a `@MainActor` view model exposing a `Loadable` state;
  `APIClient` is an `actor`. A permissive `JSONValue` type absorbs the fact that FastF1
  emits numbers where Ergast emits strings for the same fields.
- **Backend:** a thin serialisation layer (`fastf1_service.py`) converts pandas
  `Timedelta`/`Timestamp`/`NaN` values into JSON-safe output, wrapped by a small cached
  FastAPI app (`main.py`).

## 6. Data & attribution

Data is sourced live by FastF1 from the F1 live-timing API and the Ergast/Jolpica database.
This is an unofficial project and is not associated with Formula 1 companies. F1, FORMULA 1
and related marks are trademarks of Formula One Licensing BV.
