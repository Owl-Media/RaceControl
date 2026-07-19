"""
fastf1_service.py
-----------------
Data-access layer that wraps the FastF1 Python library (https://docs.fastf1.dev)
and the Ergast/Jolpica backend, converting pandas structures into clean,
JSON-serialisable dictionaries for the RaceControl iOS app.

Everything here is defensive: FastF1 returns pandas DataFrames full of
Timedelta / Timestamp / NaN values that do not serialise to JSON on their own,
so every value passes through a normaliser before leaving this module.
"""

from __future__ import annotations

import logging
import math
import os
from datetime import datetime, timedelta
from functools import lru_cache
from typing import Any, Optional

import fastf1
import pandas as pd
from fastf1.ergast import Ergast

log = logging.getLogger("racecontrol")

# FastF1 has full timing/telemetry support from 2018 onwards.
MIN_YEAR = 2018

_ergast = Ergast()


def configure_cache(cache_dir: str) -> None:
    """Enable FastF1's on-disk cache. Must be called once at startup."""
    fastf1.Cache.enable_cache(cache_dir)
    fastf1.set_log_level("WARNING")


# --------------------------------------------------------------------------- #
#  Normalisation helpers
# --------------------------------------------------------------------------- #
def _clean(value: Any) -> Any:
    """Turn any pandas / numpy / datetime scalar into a JSON-safe value."""
    if value is None:
        return None
    # pandas NaT / NaN
    try:
        if value is pd.NaT or (isinstance(value, float) and math.isnan(value)):
            return None
    except (TypeError, ValueError):
        pass
    if isinstance(value, (pd.Timedelta, timedelta)):
        return None  # timedeltas are exposed explicitly as *_ms fields instead
    if isinstance(value, (pd.Timestamp, datetime)):
        return value.isoformat()
    # numpy scalar -> python scalar
    if hasattr(value, "item"):
        try:
            return value.item()
        except (ValueError, AttributeError):
            return str(value)
    if isinstance(value, float) and (math.isinf(value) or math.isnan(value)):
        return None
    return value


def _td_ms(value: Any) -> Optional[int]:
    """Timedelta -> whole milliseconds, or None."""
    if value is None or value is pd.NaT:
        return None
    if isinstance(value, (pd.Timedelta, timedelta)):
        try:
            return int(value.total_seconds() * 1000)
        except (ValueError, OverflowError):
            return None
    if isinstance(value, float) and math.isnan(value):
        return None
    return None


def _fmt_lap(value: Any) -> Optional[str]:
    """Timedelta -> 'm:ss.mmm' lap-time string, or None."""
    ms = _td_ms(value)
    if ms is None or ms <= 0:
        return None
    minutes, rem = divmod(ms, 60_000)
    seconds, millis = divmod(rem, 1000)
    return f"{minutes}:{seconds:02d}.{millis:03d}"


def _row(series: pd.Series, mapping: dict[str, str]) -> dict[str, Any]:
    """Pull mapped columns out of a pandas row, cleaning each value."""
    out: dict[str, Any] = {}
    for out_key, col in mapping.items():
        out[out_key] = _clean(series.get(col)) if col in series else None
    return out


def _hex_color(raw: Any) -> Optional[str]:
    if raw is None:
        return None
    s = str(raw).strip()
    if not s or s.lower() in ("nan", "none"):
        return None
    return f"#{s}" if not s.startswith("#") else s


def _collect_multi(resp, max_pages: int = 25):
    """Walk every page of an Ergast/Jolpica multi-response.

    Jolpica (the Ergast successor FastF1 now uses) caps ``limit`` at 100 rows
    per page, so a full season of race/qualifying results spans several pages.
    This gathers all per-race content frames plus a concatenated description
    frame (round / raceName metadata) so nothing is silently truncated.
    """
    contents = list(resp.content)
    descs = [resp.description]
    pages = 0
    while not resp.is_complete and pages < max_pages:
        try:
            resp = resp.get_next_result_page()
        except Exception as exc:  # noqa: BLE001
            log.warning("pagination stopped early: %s", exc)
            break
        contents.extend(resp.content)
        descs.append(resp.description)
        pages += 1
    description = pd.concat(descs, ignore_index=True) if descs else pd.DataFrame()
    return contents, description


# --------------------------------------------------------------------------- #
#  Session loading (cached in-memory)
# --------------------------------------------------------------------------- #
# NB: FastF1's load() swallows internal failures (`@soft_exceptions`), so a
# transient F1/Jolpica hiccup can return a session with no results/laps. We must
# NOT cache such a broken session, otherwise every later request re-serves the
# failure. This manual cache only stores loads that actually produced data.
_SESSION_CACHE: dict = {}
_SESSION_ORDER: list = []
# Lower this on a memory-constrained container — a loaded race session with
# telemetry can be tens of megabytes.
_SESSION_CACHE_MAX = int(os.environ.get("SESSION_CACHE_MAX", 48))


def _session_has_data(session, laps_requested: bool) -> bool:
    try:
        if session.results is not None and len(session.results):
            return True
    except Exception:  # noqa: BLE001
        pass
    if laps_requested:
        try:
            if session.laps is not None and len(session.laps):
                return True
        except Exception:  # noqa: BLE001
            pass
    return False


def _load_session(year: int, rnd: int, identifier: str, with_laps: bool,
                  with_telemetry: bool = False, force: bool = False):
    key = (year, rnd, identifier, with_laps, with_telemetry)
    if not force and key in _SESSION_CACHE:
        return _SESSION_CACHE[key]

    session = fastf1.get_session(year, rnd, identifier)
    # Position/telemetry traces (used for the circuit map) are only available
    # when telemetry is loaded; loading it also implies loading laps.
    load_laps = with_laps or with_telemetry
    session.load(
        laps=load_laps,
        telemetry=with_telemetry,
        weather=False,
        messages=False,
    )

    # Only cache a load that actually produced usable data.
    if _session_has_data(session, load_laps):
        _SESSION_CACHE[key] = session
        _SESSION_ORDER.append(key)
        if len(_SESSION_ORDER) > _SESSION_CACHE_MAX:
            old = _SESSION_ORDER.pop(0)
            _SESSION_CACHE.pop(old, None)
    return session


# --------------------------------------------------------------------------- #
#  Seasons & schedule
# --------------------------------------------------------------------------- #
def get_seasons() -> list[int]:
    current = datetime.now().year
    return list(range(current, MIN_YEAR - 1, -1))


def get_schedule(year: int) -> list[dict[str, Any]]:
    schedule = fastf1.get_event_schedule(year, include_testing=False)
    now = datetime.now()
    events: list[dict[str, Any]] = []
    for _, ev in schedule.iterrows():
        sessions = []
        for i in range(1, 6):
            name = ev.get(f"Session{i}")
            date = ev.get(f"Session{i}DateUtc")
            if name and str(name) != "None" and not pd.isna(name):
                sessions.append(
                    {
                        "name": _clean(name),
                        "date": _clean(date),
                        "identifier": _session_identifier(str(name)),
                    }
                )
        event_date = ev.get("EventDate")
        completed = False
        if isinstance(event_date, (pd.Timestamp, datetime)) and not pd.isna(event_date):
            completed = event_date.to_pydatetime().replace(tzinfo=None) < now
        events.append(
            {
                "round": int(ev.get("RoundNumber", 0)),
                "name": _clean(ev.get("EventName")),
                "officialName": _clean(ev.get("OfficialEventName")),
                "country": _clean(ev.get("Country")),
                "location": _clean(ev.get("Location")),
                "date": _clean(event_date),
                "format": _clean(ev.get("EventFormat")),
                "sessions": sessions,
                "completed": completed,
                "year": year,
            }
        )
    return events


def _session_identifier(name: str) -> str:
    lookup = {
        "Practice 1": "FP1",
        "Practice 2": "FP2",
        "Practice 3": "FP3",
        "Qualifying": "Q",
        "Sprint": "S",
        "Sprint Qualifying": "SQ",
        "Sprint Shootout": "SS",
        "Race": "R",
    }
    return lookup.get(name, name)


# --------------------------------------------------------------------------- #
#  Session results
# --------------------------------------------------------------------------- #
def _safe_results(session):
    """Return the results DataFrame, or None if it never loaded."""
    try:
        res = session.results
        return res if res is not None and len(res) else None
    except Exception:  # noqa: BLE001
        return None


def get_results(year: int, rnd: int, identifier: str = "R") -> dict[str, Any]:
    session = _load_session(year, rnd, identifier, with_laps=False)
    results = _safe_results(session)

    # If the initial (results-only) load came back empty — e.g. a transient
    # F1/Jolpica failure that FastF1 swallowed — force a fresh load *with* laps.
    # That both retries the sources and enables FastF1's lap-time fallback that
    # reconstructs finishing order when API results are unavailable.
    if results is None:
        session = _load_session(year, rnd, identifier, with_laps=True, force=True)
        results = _safe_results(session)

    rows: list[dict[str, Any]] = []
    for _, r in (results.iterrows() if results is not None else []):
        time_ms = _td_ms(r.get("Time"))
        rows.append(
            {
                "position": _clean(r.get("Position")),
                "classifiedPosition": _clean(r.get("ClassifiedPosition")),
                "driverNumber": _clean(r.get("DriverNumber")),
                "abbreviation": _clean(r.get("Abbreviation")),
                "driverId": _clean(r.get("DriverId")),
                "firstName": _clean(r.get("FirstName")),
                "lastName": _clean(r.get("LastName")),
                "fullName": _clean(r.get("FullName")),
                "headshotUrl": _clean(r.get("HeadshotUrl")),
                "countryCode": _clean(r.get("CountryCode")),
                "teamName": _clean(r.get("TeamName")),
                "teamId": _clean(r.get("TeamId")),
                "teamColor": _hex_color(r.get("TeamColor")),
                "gridPosition": _clean(r.get("GridPosition")),
                "status": _clean(r.get("Status")),
                "points": _clean(r.get("Points")),
                "timeMs": time_ms,
                "q1": _fmt_lap(r.get("Q1")),
                "q2": _fmt_lap(r.get("Q2")),
                "q3": _fmt_lap(r.get("Q3")),
            }
        )

    return {
        "year": year,
        "round": rnd,
        "session": identifier,
        "sessionName": _clean(getattr(session, "name", identifier)),
        "eventName": _clean(session.event.get("EventName")),
        "totalLaps": _safe_total_laps(session),
        "results": rows,
    }


def _safe_total_laps(session):
    """`session.total_laps` raises if laps weren't loaded — return None instead."""
    try:
        return _clean(session.total_laps)
    except Exception:  # noqa: BLE001
        return None


# --------------------------------------------------------------------------- #
#  Standings (Ergast / Jolpica)
# --------------------------------------------------------------------------- #
def get_driver_standings(year: int) -> list[dict[str, Any]]:
    resp = _ergast.get_driver_standings(season=year, limit=100)
    if not resp.content:
        return []
    df = resp.content[0]
    out = []
    for _, r in df.iterrows():
        constructors = r.get("constructorNames")
        team = constructors[0] if isinstance(constructors, list) and constructors else None
        cids = r.get("constructorIds")
        team_id = cids[0] if isinstance(cids, list) and cids else None
        out.append(
            {
                "position": _clean(r.get("position")),
                "points": _clean(r.get("points")),
                "wins": _clean(r.get("wins")),
                "driverId": _clean(r.get("driverId")),
                "driverNumber": _clean(r.get("driverNumber")),
                "driverCode": _clean(r.get("driverCode")),
                "givenName": _clean(r.get("givenName")),
                "familyName": _clean(r.get("familyName")),
                "nationality": _clean(r.get("driverNationality")),
                "dateOfBirth": _clean(r.get("dateOfBirth")),
                "teamName": _clean(team),
                "teamId": _clean(team_id),
            }
        )
    return out


def get_constructor_standings(year: int) -> list[dict[str, Any]]:
    resp = _ergast.get_constructor_standings(season=year, limit=100)
    if not resp.content:
        return []
    df = resp.content[0]
    out = []
    for _, r in df.iterrows():
        out.append(
            {
                "position": _clean(r.get("position")),
                "points": _clean(r.get("points")),
                "wins": _clean(r.get("wins")),
                "teamId": _clean(r.get("constructorId")),
                "teamName": _clean(r.get("constructorName")),
                "nationality": _clean(r.get("constructorNationality")),
            }
        )
    return out


# --------------------------------------------------------------------------- #
#  Drivers & teams (enriched from the season's first completed race)
# --------------------------------------------------------------------------- #
def _season_reference_results(year: int) -> Optional[pd.DataFrame]:
    """Grab a race's results for headshots / team colours (metadata Ergast lacks)."""
    try:
        schedule = fastf1.get_event_schedule(year, include_testing=False)
    except Exception as exc:  # noqa: BLE001
        log.warning("schedule lookup failed for %s: %s", year, exc)
        return None
    now = datetime.now()
    completed_rounds = [
        int(ev["RoundNumber"])
        for _, ev in schedule.iterrows()
        if isinstance(ev.get("EventDate"), (pd.Timestamp, datetime))
        and ev["EventDate"].to_pydatetime().replace(tzinfo=None) < now
        and int(ev["RoundNumber"]) > 0
    ]
    for rnd in reversed(completed_rounds):  # newest completed race = latest lineup
        try:
            session = _load_session(year, rnd, "R", with_laps=False)
            if session.results is not None and len(session.results):
                return session.results
        except Exception as exc:  # noqa: BLE001
            log.warning("results lookup failed %s r%s: %s", year, rnd, exc)
            continue
    return None


def get_drivers(year: int) -> list[dict[str, Any]]:
    standings = {d["driverId"]: d for d in get_driver_standings(year)}
    ref = _season_reference_results(year)
    meta: dict[str, dict[str, Any]] = {}
    if ref is not None:
        for _, r in ref.iterrows():
            did = _clean(r.get("DriverId"))
            if did:
                meta[did] = {
                    "headshotUrl": _clean(r.get("HeadshotUrl")),
                    "teamColor": _hex_color(r.get("TeamColor")),
                    "teamId": _clean(r.get("TeamId")),
                    "abbreviation": _clean(r.get("Abbreviation")),
                    "driverNumber": _clean(r.get("DriverNumber")),
                    "countryCode": _clean(r.get("CountryCode")),
                }

    drivers = []
    for did, s in standings.items():
        m = meta.get(did, {})
        drivers.append(
            {
                "driverId": did,
                "givenName": s.get("givenName"),
                "familyName": s.get("familyName"),
                "code": s.get("driverCode") or m.get("abbreviation"),
                "number": s.get("driverNumber") or m.get("driverNumber"),
                "nationality": s.get("nationality"),
                "dateOfBirth": s.get("dateOfBirth"),
                "teamName": s.get("teamName"),
                "teamId": s.get("teamId") or m.get("teamId"),
                "teamColor": m.get("teamColor"),
                "headshotUrl": m.get("headshotUrl"),
                "countryCode": m.get("countryCode"),
                "position": s.get("position"),
                "points": s.get("points"),
                "wins": s.get("wins"),
            }
        )
    # Any driver in the reference lineup missing from standings (rare) still appears.
    return drivers


def get_driver_detail(year: int, driver_id: str) -> dict[str, Any]:
    drivers = {d["driverId"]: d for d in get_drivers(year)}
    base = drivers.get(driver_id, {"driverId": driver_id})

    # Per-round results for this driver across the season.
    # NB: race metadata (round, raceName) lives in `.description`, while the
    # per-driver result rows live in the matching `.content` DataFrame.
    results_resp = _ergast.get_race_results(season=year, limit=100)
    contents, description = _collect_multi(results_resp)
    season_rows: list[dict[str, Any]] = []
    for idx, race_df in enumerate(contents):
        if race_df is None or race_df.empty or "driverId" not in race_df:
            continue
        meta = description.iloc[idx] if idx < len(description) else None
        rnd = int(meta["round"]) if meta is not None and "round" in meta else None
        race_name = _clean(meta.get("raceName")) if meta is not None and "raceName" in meta else None
        match = race_df[race_df["driverId"] == driver_id]
        if match.empty:
            continue
        r = match.iloc[0]
        season_rows.append(
            {
                "round": rnd,
                "raceName": race_name,
                "position": _clean(r.get("position")),
                "points": _clean(r.get("points")),
                "grid": _clean(r.get("grid")),
                "status": _clean(r.get("status")),
            }
        )
    season_rows.sort(key=lambda x: x["round"] if x["round"] is not None else 0)
    base["seasonResults"] = season_rows
    return base


def get_teams(year: int) -> list[dict[str, Any]]:
    standings = get_constructor_standings(year)
    drivers = get_drivers(year)
    colors: dict[str, Optional[str]] = {}
    roster: dict[str, list[dict[str, Any]]] = {}
    for d in drivers:
        tid = d.get("teamId")
        if not tid:
            continue
        colors.setdefault(tid, d.get("teamColor"))
        roster.setdefault(tid, []).append(
            {
                "driverId": d["driverId"],
                "name": f'{d.get("givenName","")} {d.get("familyName","")}'.strip(),
                "code": d.get("code"),
                "number": d.get("number"),
                "headshotUrl": d.get("headshotUrl"),
            }
        )
    teams = []
    for t in standings:
        tid = t["teamId"]
        teams.append(
            {
                **t,
                "teamColor": colors.get(tid),
                "drivers": roster.get(tid, []),
            }
        )
    return teams


def get_team_detail(year: int, team_id: str) -> dict[str, Any]:
    for t in get_teams(year):
        if t["teamId"] == team_id:
            return t
    return {"teamId": team_id, "drivers": []}


# --------------------------------------------------------------------------- #
#  Circuits & circuit map
# --------------------------------------------------------------------------- #
def get_circuits(year: int) -> list[dict[str, Any]]:
    resp = _ergast.get_circuits(season=year, limit=100)
    df = resp
    out = []
    for _, r in df.iterrows():
        out.append(
            {
                "circuitId": _clean(r.get("circuitId")),
                "name": _clean(r.get("circuitName")),
                "locality": _clean(r.get("locality")),
                "country": _clean(r.get("country")),
                "lat": _clean(r.get("lat")),
                "long": _clean(r.get("long")),
            }
        )
    return out


def get_circuit_map(year: int, rnd: int) -> dict[str, Any]:
    """Track outline + corner markers derived from a fast lap's position trace.

    Returns an empty outline/corners list (rather than erroring) when the session
    has no data yet — e.g. a future or very recently finished race.
    """
    session = _load_session(year, rnd, "R", with_laps=True, with_telemetry=True)
    payload: dict[str, Any] = {
        "year": year,
        "round": rnd,
        "eventName": _clean(session.event.get("EventName")),
        "location": _clean(session.event.get("Location")),
        "country": _clean(session.event.get("Country")),
        "outline": [],
        "points": [],
        "corners": [],
        "rotation": 0,
        "lengthMeters": None,
        "minElevation": None,
        "maxElevation": None,
        "fastestLap": None,
    }
    try:
        laps = session.laps
        if laps is None or not len(laps):
            return payload  # session not available / no timing data
        lap = laps.pick_fastest()

        # Merged telemetry gives X/Y/Z position aligned with speed, DRS and the
        # cumulative distance along the lap — everything we need to draw a
        # speed-coloured racing line with DRS zones and an elevation profile.
        tel = lap.get_telemetry()
        step = max(1, len(tel) // 350)  # cap resolution for the wire
        tel = tel.iloc[::step]

        xs = tel["X"].to_numpy()
        ys = tel["Y"].to_numpy()
        zs = tel["Z"].to_numpy() if "Z" in tel else [0.0] * len(xs)
        speeds = tel["Speed"].to_numpy()
        drs = tel["DRS"].to_numpy() if "DRS" in tel else [0] * len(xs)
        dist = tel["Distance"].to_numpy() if "Distance" in tel else range(len(xs))

        points = []
        for x, y, z, sp, dr, ds in zip(xs, ys, zs, speeds, drs, dist):
            points.append({
                "x": float(x),
                "y": float(y),
                "z": float(z),
                "speed": round(float(sp), 1),
                "drs": int(dr),               # 10/12/14 => DRS open
                "distance": round(float(ds), 1),
            })
        payload["points"] = points
        payload["outline"] = [{"x": p["x"], "y": p["y"]} for p in points]  # back-compat

        if len(dist):
            payload["lengthMeters"] = round(float(max(dist)))
        if len(zs):
            payload["minElevation"] = round(float(min(zs)), 1)
            payload["maxElevation"] = round(float(max(zs)), 1)

        drv = session.get_driver(lap["Driver"]) if lap.get("Driver") else None
        payload["fastestLap"] = {
            "driver": _clean(lap.get("Driver")),
            "driverName": _clean(drv["FullName"]) if drv is not None else None,
            "team": _clean(drv["TeamName"]) if drv is not None else None,
            "teamColor": _hex_color(drv["TeamColor"]) if drv is not None else None,
            "time": _fmt_lap(lap.get("LapTime")),
            "compound": _clean(lap.get("Compound")),
        }
    except Exception as exc:  # noqa: BLE001
        log.warning("pos data unavailable %s r%s: %s", year, rnd, exc)
    try:
        info = session.get_circuit_info()
        payload["rotation"] = float(info.rotation)
        for _, c in info.corners.iterrows():
            payload["corners"].append(
                {
                    "number": int(c["Number"]),
                    "letter": _clean(c.get("Letter")) or "",
                    "x": float(c["X"]),
                    "y": float(c["Y"]),
                }
            )
    except Exception as exc:  # noqa: BLE001
        log.warning("circuit info unavailable %s r%s: %s", year, rnd, exc)
    return payload


# --------------------------------------------------------------------------- #
#  Race replay (lap-by-lap running order)
# --------------------------------------------------------------------------- #
def get_race_replay(year: int, rnd: int) -> dict[str, Any]:
    """
    Build a lap-by-lap running order for the race so the app can 'replay' it:
    for every completed lap we emit the ordered field with gaps, tyre and lap time.
    """
    session = _load_session(year, rnd, "R", with_laps=True)
    empty = {
        "year": year, "round": rnd,
        "eventName": _clean(session.event.get("EventName")),
        "totalLaps": 0, "drivers": [], "frames": [],
    }
    try:
        laps = session.laps
        results = session.results
        if laps is None or not len(laps):
            return empty  # session not available / no timing data yet
    except Exception as exc:  # noqa: BLE001
        log.warning("replay data unavailable %s r%s: %s", year, rnd, exc)
        return empty

    # Driver metadata for colouring / labels.
    meta: dict[str, dict[str, Any]] = {}
    for _, r in results.iterrows():
        abbr = _clean(r.get("Abbreviation"))
        if abbr:
            meta[abbr] = {
                "driverId": _clean(r.get("DriverId")),
                "fullName": _clean(r.get("FullName")),
                "teamName": _clean(r.get("TeamName")),
                "teamColor": _hex_color(r.get("TeamColor")),
                "number": _clean(r.get("DriverNumber")),
            }

    total_laps = int(laps["LapNumber"].max()) if len(laps) else 0
    frames: list[dict[str, Any]] = []

    for lap_no in range(1, total_laps + 1):
        lap_slice = laps[laps["LapNumber"] == lap_no]
        entries = []
        for _, lp in lap_slice.iterrows():
            pos = lp.get("Position")
            if pd.isna(pos):
                continue
            abbr = _clean(lp.get("Driver"))
            m = meta.get(abbr, {})
            entries.append(
                {
                    "position": int(pos),
                    "driver": abbr,
                    "driverId": m.get("driverId"),
                    "teamColor": m.get("teamColor"),
                    "teamName": m.get("teamName"),
                    "lapTimeMs": _td_ms(lp.get("LapTime")),
                    "lapTime": _fmt_lap(lp.get("LapTime")),
                    "compound": _clean(lp.get("Compound")),
                    "tyreLife": _clean(lp.get("TyreLife")),
                }
            )
        entries.sort(key=lambda e: e["position"])
        if entries:
            frames.append({"lap": lap_no, "order": entries})

    return {
        "year": year,
        "round": rnd,
        "eventName": _clean(session.event.get("EventName")),
        "totalLaps": total_laps,
        "drivers": [
            {"code": k, **v} for k, v in meta.items()
        ],
        "frames": frames,
    }


# --------------------------------------------------------------------------- #
#  Driver metadata helper (colours / names) from a session's results
# --------------------------------------------------------------------------- #
def _driver_meta(session) -> dict[str, dict[str, Any]]:
    meta: dict[str, dict[str, Any]] = {}
    try:
        for _, r in session.results.iterrows():
            abbr = _clean(r.get("Abbreviation"))
            if abbr:
                meta[abbr] = {
                    "driverId": _clean(r.get("DriverId")),
                    "fullName": _clean(r.get("FullName")),
                    "teamName": _clean(r.get("TeamName")),
                    "teamColor": _hex_color(r.get("TeamColor")),
                    "number": _clean(r.get("DriverNumber")),
                }
    except Exception as exc:  # noqa: BLE001
        log.warning("driver meta unavailable: %s", exc)
    return meta


# --------------------------------------------------------------------------- #
#  Lap-time evolution
# --------------------------------------------------------------------------- #
def get_lap_times(year: int, rnd: int) -> dict[str, Any]:
    """Per-driver lap-time series for the race, for a lap-time evolution chart."""
    session = _load_session(year, rnd, "R", with_laps=True)
    empty = {"year": year, "round": rnd,
             "eventName": _clean(session.event.get("EventName")),
             "totalLaps": 0, "drivers": []}
    try:
        laps = session.laps
        if laps is None or not len(laps):
            return empty
    except Exception as exc:  # noqa: BLE001
        log.warning("laptimes unavailable %s r%s: %s", year, rnd, exc)
        return empty

    meta = _driver_meta(session)
    out: dict[str, dict[str, Any]] = {}
    for _, lp in laps.iterrows():
        abbr = _clean(lp.get("Driver"))
        ms = _td_ms(lp.get("LapTime"))
        lap_no = lp.get("LapNumber")
        if abbr is None or ms is None or pd.isna(lap_no):
            continue
        m = meta.get(abbr, {})
        entry = out.setdefault(abbr, {
            "code": abbr,
            "driverId": m.get("driverId"),
            "teamName": m.get("teamName"),
            "teamColor": m.get("teamColor"),
            "laps": [],
        })
        entry["laps"].append({
            "lap": int(lap_no),
            "timeMs": ms,
            "compound": _clean(lp.get("Compound")),
        })

    total_laps = int(laps["LapNumber"].max()) if len(laps) else 0
    drivers = sorted(out.values(), key=lambda d: d["code"])
    return {"year": year, "round": rnd,
            "eventName": _clean(session.event.get("EventName")),
            "totalLaps": total_laps, "drivers": drivers}


# --------------------------------------------------------------------------- #
#  Tyre strategy & pit stops
# --------------------------------------------------------------------------- #
def get_strategy(year: int, rnd: int) -> dict[str, Any]:
    """Per-driver stint timeline (compound + lap range) and pit-stop count."""
    session = _load_session(year, rnd, "R", with_laps=True)
    empty = {"year": year, "round": rnd,
             "eventName": _clean(session.event.get("EventName")),
             "totalLaps": 0, "drivers": []}
    try:
        laps = session.laps
        if laps is None or not len(laps):
            return empty
    except Exception as exc:  # noqa: BLE001
        log.warning("strategy unavailable %s r%s: %s", year, rnd, exc)
        return empty

    meta = _driver_meta(session)
    total_laps = int(laps["LapNumber"].max()) if len(laps) else 0
    drivers = []
    # Order drivers by finishing position where possible.
    order = list(session.results["Abbreviation"]) if session.results is not None else []
    abbrs = [a for a in order if a in set(laps["Driver"])] or sorted(set(laps["Driver"]))

    for abbr in abbrs:
        d_laps = laps[laps["Driver"] == abbr].sort_values("LapNumber")
        if d_laps.empty:
            continue
        stints = []
        pit_stops = 0
        for stint_no, s_laps in d_laps.groupby("Stint"):
            if s_laps.empty:
                continue
            comp = _clean(s_laps["Compound"].iloc[0])
            start = int(s_laps["LapNumber"].min())
            end = int(s_laps["LapNumber"].max())
            stints.append({
                "stint": int(stint_no) if not pd.isna(stint_no) else 0,
                "compound": comp,
                "startLap": start,
                "endLap": end,
                "laps": end - start + 1,
            })
        pit_stops = max(len(stints) - 1, 0)
        m = meta.get(abbr, {})
        drivers.append({
            "code": abbr,
            "driverId": m.get("driverId"),
            "teamName": m.get("teamName"),
            "teamColor": m.get("teamColor"),
            "pitStops": pit_stops,
            "stints": sorted(stints, key=lambda s: s["startLap"]),
        })

    return {"year": year, "round": rnd,
            "eventName": _clean(session.event.get("EventName")),
            "totalLaps": total_laps, "drivers": drivers}


# --------------------------------------------------------------------------- #
#  Weather
# --------------------------------------------------------------------------- #
def get_weather(year: int, rnd: int, identifier: str = "R") -> dict[str, Any]:
    """Session weather summary (temps, humidity, wind, rainfall)."""
    session = fastf1.get_session(year, rnd, identifier)
    session.load(laps=False, telemetry=False, weather=True, messages=False)
    payload: dict[str, Any] = {
        "year": year, "round": rnd, "session": identifier,
        "eventName": _clean(session.event.get("EventName")),
        "available": False,
    }
    try:
        wx = session.weather_data
        if wx is None or not len(wx):
            return payload
        def stat(col):
            if col not in wx:
                return None
            series = pd.to_numeric(wx[col], errors="coerce").dropna()
            return round(float(series.mean()), 1) if len(series) else None
        rain_any = bool(wx["Rainfall"].any()) if "Rainfall" in wx else False
        payload.update({
            "available": True,
            "airTemp": stat("AirTemp"),
            "trackTemp": stat("TrackTemp"),
            "humidity": stat("Humidity"),
            "pressure": stat("Pressure"),
            "windSpeed": stat("WindSpeed"),
            "rainfall": rain_any,
            "airTempMax": round(float(pd.to_numeric(wx["AirTemp"], errors="coerce").max()), 1) if "AirTemp" in wx else None,
            "trackTempMax": round(float(pd.to_numeric(wx["TrackTemp"], errors="coerce").max()), 1) if "TrackTemp" in wx else None,
        })
    except Exception as exc:  # noqa: BLE001
        log.warning("weather unavailable %s r%s: %s", year, rnd, exc)
    return payload


# --------------------------------------------------------------------------- #
#  Telemetry
# --------------------------------------------------------------------------- #
def _lap_telemetry(session, abbr: str, which: str = "fastest") -> Optional[dict[str, Any]]:
    d_laps = session.laps.pick_drivers(abbr)
    if d_laps is None or not len(d_laps):
        return None
    if which == "fastest":
        lap = d_laps.pick_fastest()
    else:
        try:
            lap = d_laps[d_laps["LapNumber"] == int(which)].iloc[0]
        except Exception:  # noqa: BLE001
            lap = d_laps.pick_fastest()
    if lap is None:
        return None
    tel = lap.get_telemetry()
    if tel is None or not len(tel):
        return None
    step = max(1, len(tel) // 500)
    tel = tel.iloc[::step]
    # Seconds elapsed since the start of the lap, for driver-vs-driver delta.
    try:
        tsec = (tel["Time"] - tel["Time"].iloc[0]).dt.total_seconds()
        time_s = [round(float(x), 3) for x in tsec]
    except Exception:  # noqa: BLE001
        time_s = []
    return {
        "code": abbr,
        "lapNumber": int(lap["LapNumber"]) if not pd.isna(lap.get("LapNumber")) else None,
        "lapTime": _fmt_lap(lap.get("LapTime")),
        "lapTimeMs": _td_ms(lap.get("LapTime")),
        "compound": _clean(lap.get("Compound")),
        "distance": [round(float(x), 1) for x in tel["Distance"]],
        "time": time_s,
        "speed": [round(float(x), 1) for x in tel["Speed"]],
        "throttle": [round(float(x)) for x in tel["Throttle"]],
        "brake": [int(bool(x)) for x in tel["Brake"]],
        "gear": [int(x) for x in tel["nGear"]],
        "rpm": [int(x) for x in tel["RPM"]],
        "drs": [int(x) for x in tel["DRS"]],
        "x": [float(x) for x in tel["X"]],
        "y": [float(y) for y in tel["Y"]],
    }


def get_telemetry(year: int, rnd: int, driver: str, lap: str = "fastest") -> dict[str, Any]:
    session = _load_session(year, rnd, "R", with_laps=True, with_telemetry=True)
    meta = _driver_meta(session)
    trace = _lap_telemetry(session, driver, lap)
    if trace is None:
        return {"year": year, "round": rnd, "available": False, "driver": driver}
    m = meta.get(driver, {})
    trace.update({"driverName": m.get("fullName"), "teamName": m.get("teamName"),
                  "teamColor": m.get("teamColor")})
    return {"year": year, "round": rnd, "available": True,
            "eventName": _clean(session.event.get("EventName")), "trace": trace}


def get_telemetry_compare(year: int, rnd: int, d1: str, d2: str) -> dict[str, Any]:
    session = _load_session(year, rnd, "R", with_laps=True, with_telemetry=True)
    meta = _driver_meta(session)
    traces = []
    for code in (d1, d2):
        t = _lap_telemetry(session, code, "fastest")
        if t is not None:
            m = meta.get(code, {})
            t.update({"driverName": m.get("fullName"), "teamName": m.get("teamName"),
                      "teamColor": m.get("teamColor")})
            traces.append(t)
    return {"year": year, "round": rnd,
            "eventName": _clean(session.event.get("EventName")),
            "available": len(traces) == 2, "traces": traces}


def list_race_drivers(year: int, rnd: int) -> list[dict[str, Any]]:
    """Lightweight driver list for a race (for telemetry/lap pickers)."""
    session = _load_session(year, rnd, "R", with_laps=False)
    out = []
    try:
        for _, r in session.results.iterrows():
            out.append({
                "code": _clean(r.get("Abbreviation")),
                "driverId": _clean(r.get("DriverId")),
                "fullName": _clean(r.get("FullName")),
                "teamName": _clean(r.get("TeamName")),
                "teamColor": _hex_color(r.get("TeamColor")),
                "number": _clean(r.get("DriverNumber")),
            })
    except Exception as exc:  # noqa: BLE001
        log.warning("race drivers unavailable %s r%s: %s", year, rnd, exc)
    return out


# --------------------------------------------------------------------------- #
#  Retirements (single race) & reliability (season, Ergast-based)
# --------------------------------------------------------------------------- #
def _is_finish_status(status: str) -> bool:
    if not status:
        return False
    return status == "Finished" or status.startswith("+")


def get_retirements(year: int, rnd: int) -> dict[str, Any]:
    session = _load_session(year, rnd, "R", with_laps=False)
    retirements = []
    try:
        for _, r in session.results.iterrows():
            status = _clean(r.get("Status")) or ""
            if not _is_finish_status(status):
                retirements.append({
                    "driver": _clean(r.get("Abbreviation")),
                    "fullName": _clean(r.get("FullName")),
                    "driverId": _clean(r.get("DriverId")),
                    "teamName": _clean(r.get("TeamName")),
                    "teamColor": _hex_color(r.get("TeamColor")),
                    "status": status,
                    "classifiedPosition": _clean(r.get("ClassifiedPosition")),
                })
    except Exception as exc:  # noqa: BLE001
        log.warning("retirements unavailable %s r%s: %s", year, rnd, exc)
    return {"year": year, "round": rnd,
            "eventName": _clean(session.event.get("EventName")),
            "retirements": retirements}


# Group raw Ergast status strings into human categories.
_MECHANICAL = {
    "Engine", "Power Unit", "Gearbox", "Hydraulics", "Transmission", "Electrical",
    "Turbo", "Brakes", "Suspension", "Clutch", "Fuel system", "Fuel pump",
    "Cooling", "Oil leak", "Water leak", "Exhaust", "Driveshaft", "Wheel",
    "Overheating", "Battery", "ERS", "Radiator", "Vibrations", "Throttle",
    "Differential", "Mechanical", "Steering", "Oil pressure", "Fuel pressure",
}
_COLLISION = {"Accident", "Collision", "Collision damage", "Spun off", "Damage", "Puncture"}


def _classify_status(status: str) -> str:
    if _is_finish_status(status):
        return "Finished"
    if status in _COLLISION:
        return "Accident"
    if status in _MECHANICAL:
        return "Mechanical"
    if status == "Disqualified":
        return "Disqualified"
    if status in ("Retired", "Withdrew", "Did not start", "Did not qualify"):
        return "Other"
    return "Mechanical" if status else "Other"


def get_reliability(year: int) -> dict[str, Any]:
    """Season DNF breakdown per driver and per team, derived from Ergast results."""
    resp = _ergast.get_race_results(season=year, limit=100)
    contents, _ = _collect_multi(resp)
    drivers: dict[str, dict[str, Any]] = {}
    teams: dict[str, dict[str, Any]] = {}
    races = 0

    for race_df in contents:
        if race_df is None or race_df.empty or "status" not in race_df:
            continue
        races += 1
        for _, r in race_df.iterrows():
            status = _clean(r.get("status")) or ""
            cat = _classify_status(status)
            did = _clean(r.get("driverId"))
            tid = _clean(r.get("constructorId"))
            name = f'{_clean(r.get("givenName")) or ""} {_clean(r.get("familyName")) or ""}'.strip()
            if did:
                d = drivers.setdefault(did, {
                    "driverId": did, "name": name, "teamId": tid,
                    "finished": 0, "mechanical": 0, "accident": 0,
                    "disqualified": 0, "other": 0, "dnf": 0, "starts": 0,
                })
                d["starts"] += 1
                key = {"Finished": "finished", "Mechanical": "mechanical",
                       "Accident": "accident", "Disqualified": "disqualified",
                       "Other": "other"}[cat]
                d[key] += 1
                if cat != "Finished":
                    d["dnf"] += 1
            if tid:
                t = teams.setdefault(tid, {
                    "teamId": tid, "teamName": _clean(r.get("constructorName")),
                    "finished": 0, "mechanical": 0, "accident": 0,
                    "disqualified": 0, "other": 0, "dnf": 0, "starts": 0,
                })
                t["starts"] += 1
                key = {"Finished": "finished", "Mechanical": "mechanical",
                       "Accident": "accident", "Disqualified": "disqualified",
                       "Other": "other"}[cat]
                t[key] += 1
                if cat != "Finished":
                    t["dnf"] += 1

    def finish_rate(x):
        return round(100 * x["finished"] / x["starts"], 1) if x["starts"] else 0.0
    driver_list = sorted(drivers.values(), key=lambda x: (-x["dnf"], x["name"]))
    for d in driver_list:
        d["finishRate"] = finish_rate(d)
    team_list = sorted(teams.values(), key=lambda x: (-x["dnf"], x["teamName"] or ""))
    for t in team_list:
        t["finishRate"] = finish_rate(t)

    return {"year": year, "races": races, "drivers": driver_list, "teams": team_list}


# --------------------------------------------------------------------------- #
#  Head-to-head driver comparison (season, Ergast-based)
# --------------------------------------------------------------------------- #
def get_compare(year: int, d1: str, d2: str) -> dict[str, Any]:
    race_resp = _ergast.get_race_results(season=year, limit=100)
    race_contents, desc = _collect_multi(race_resp)
    qual_resp = _ergast.get_qualifying_results(season=year, limit=100)
    qual_contents, _ = _collect_multi(qual_resp)

    def blank(did):
        return {"driverId": did, "name": did, "teamName": None,
                "points": 0.0, "wins": 0, "podiums": 0, "poles": 0,
                "bestFinish": None, "dnf": 0, "raceWins_h2h": 0, "qualWins_h2h": 0,
                "rounds": []}

    agg = {d1: blank(d1), d2: blank(d2)}

    # Race results
    for idx, race_df in enumerate(race_contents):
        if race_df is None or race_df.empty or "driverId" not in race_df:
            continue
        rnd = int(desc.iloc[idx]["round"]) if idx < len(desc) and "round" in desc else None
        race_name = _clean(desc.iloc[idx].get("raceName")) if idx < len(desc) else None
        pos = {}
        for did in (d1, d2):
            row = race_df[race_df["driverId"] == did]
            if row.empty:
                continue
            r = row.iloc[0]
            a = agg[did]
            p = r.get("position")
            pi = int(p) if p is not None and not pd.isna(p) else None
            pts = float(r.get("points")) if r.get("points") is not None and not pd.isna(r.get("points")) else 0.0
            status = _clean(r.get("status")) or ""
            a["points"] += pts
            a["name"] = f'{_clean(r.get("givenName")) or ""} {_clean(r.get("familyName")) or ""}'.strip() or did
            a["teamName"] = _clean(r.get("constructorName")) or a["teamName"]
            if pi == 1:
                a["wins"] += 1
            if pi is not None and pi <= 3:
                a["podiums"] += 1
            if pi is not None and (a["bestFinish"] is None or pi < a["bestFinish"]):
                a["bestFinish"] = pi
            if not _is_finish_status(status):
                a["dnf"] += 1
            if pi is not None:
                pos[did] = pi
            a["rounds"].append({"round": rnd, "raceName": race_name, "position": pi})
        if d1 in pos and d2 in pos:
            if pos[d1] < pos[d2]:
                agg[d1]["raceWins_h2h"] += 1
            elif pos[d2] < pos[d1]:
                agg[d2]["raceWins_h2h"] += 1

    # Qualifying head-to-head + poles
    try:
        for q_df in qual_contents:
            if q_df is None or q_df.empty or "driverId" not in q_df:
                continue
            qpos = {}
            for did in (d1, d2):
                row = q_df[q_df["driverId"] == did]
                if row.empty:
                    continue
                p = row.iloc[0].get("position")
                pi = int(p) if p is not None and not pd.isna(p) else None
                if pi == 1:
                    agg[did]["poles"] += 1
                if pi is not None:
                    qpos[did] = pi
            if d1 in qpos and d2 in qpos:
                if qpos[d1] < qpos[d2]:
                    agg[d1]["qualWins_h2h"] += 1
                elif qpos[d2] < qpos[d1]:
                    agg[d2]["qualWins_h2h"] += 1
    except Exception as exc:  # noqa: BLE001
        log.warning("qualifying compare unavailable %s: %s", year, exc)

    for a in agg.values():
        a["points"] = round(a["points"], 1)
    return {"year": year, "drivers": [agg[d1], agg[d2]]}


# --------------------------------------------------------------------------- #
#  Standings evolution (cumulative points per round)
# --------------------------------------------------------------------------- #
def get_standings_evolution(year: int) -> dict[str, Any]:
    """Round-by-round cumulative championship points per driver.

    Combines race and sprint points from Ergast/Jolpica so the progression
    matches the official championship.
    """
    race_resp = _ergast.get_race_results(season=year, limit=100)
    race_contents, race_desc = _collect_multi(race_resp)

    # Sprint points keyed by (round, driverId).
    sprint_points: dict[tuple[int, str], float] = {}
    try:
        sr = _ergast.get_sprint_results(season=year, limit=100)
        s_contents, s_desc = _collect_multi(sr)
        for idx, df in enumerate(s_contents):
            if df is None or df.empty or "driverId" not in df:
                continue
            rnd = int(s_desc.iloc[idx]["round"]) if idx < len(s_desc) and "round" in s_desc else None
            if rnd is None:
                continue
            for _, r in df.iterrows():
                did = _clean(r.get("driverId"))
                pts = r.get("points")
                if did and pts is not None and not pd.isna(pts):
                    sprint_points[(rnd, did)] = sprint_points.get((rnd, did), 0.0) + float(pts)
    except Exception as exc:  # noqa: BLE001
        log.warning("sprint results unavailable %s: %s", year, exc)

    # Colours from the season driver list.
    colors = {d["driverId"]: d.get("teamColor") for d in get_drivers(year)}

    running: dict[str, float] = {}
    series: dict[str, list[dict[str, Any]]] = {}
    meta: dict[str, dict[str, Any]] = {}
    rounds: list[int] = []

    for idx, df in enumerate(race_contents):
        if df is None or df.empty or "driverId" not in df:
            continue
        rnd = int(race_desc.iloc[idx]["round"]) if idx < len(race_desc) and "round" in race_desc else None
        if rnd is None:
            continue
        rounds.append(rnd)

        for _, r in df.iterrows():
            did = _clean(r.get("driverId"))
            if not did:
                continue
            pts = r.get("points")
            gained = float(pts) if pts is not None and not pd.isna(pts) else 0.0
            gained += sprint_points.get((rnd, did), 0.0)
            running[did] = running.get(did, 0.0) + gained
            meta[did] = {
                "driverId": did,
                "name": f'{_clean(r.get("givenName")) or ""} {_clean(r.get("familyName")) or ""}'.strip(),
                "code": _clean(r.get("driverCode")),
                "teamName": _clean(r.get("constructorName")),
                "teamColor": colors.get(did),
            }

        # Snapshot cumulative points for every driver seen so far.
        for did in meta:
            series.setdefault(did, []).append({"round": rnd, "points": round(running.get(did, 0.0), 1)})

    drivers = []
    for did, m in meta.items():
        drivers.append({**m, "points": round(running.get(did, 0.0), 1), "series": series.get(did, [])})
    drivers.sort(key=lambda d: -d["points"])

    return {"year": year, "rounds": rounds, "drivers": drivers}
