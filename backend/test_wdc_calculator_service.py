"""
Offline tests for `fastf1_service.get_wdc_calculator`, the "who can still
win the WDC" title decider, following FastF1's own example methodology
(https://docs.fastf1.dev/gen_modules/examples_gallery/standings/plot_who_can_still_win_wdc.html):
theoretical max points remaining vs. the championship leader's current total.

`get_wdc_calculator` composes `get_drivers` and `get_schedule`, both of which
go through several pages of Ergast/FastF1 calls, stubbing that whole chain
isn't worth it here, so these tests monkeypatch the two composed functions
directly (same approach as test_teams_service.py).

    python test_wdc_calculator_service.py     (or: pytest test_wdc_calculator_service.py)
"""

import fastf1_service as svc


def _drivers():
    return [
        {"driverId": "verstappen", "givenName": "Max", "familyName": "Verstappen", "code": "VER",
         "position": 1, "points": 400, "teamName": "Red Bull", "teamId": "red_bull",
         "teamLogoUrl": None, "teamColor": "3671C6", "headshotUrl": None},
        {"driverId": "norris", "givenName": "Lando", "familyName": "Norris", "code": "NOR",
         "position": 2, "points": 350, "teamName": "McLaren", "teamId": "mclaren",
         "teamLogoUrl": None, "teamColor": "FF8000", "headshotUrl": None},
        {"driverId": "leclerc", "givenName": "Charles", "familyName": "Leclerc", "code": "LEC",
         "position": 3, "points": 200, "teamName": "Ferrari", "teamId": "ferrari",
         "teamLogoUrl": None, "teamColor": "E8002D", "headshotUrl": None},
    ]


def _remaining_events(n_conventional=0, n_sprint=0, completed_conventional=0):
    events = []
    rnd = 1
    for _ in range(completed_conventional):
        events.append({"round": rnd, "format": "conventional", "completed": True})
        rnd += 1
    for _ in range(n_conventional):
        events.append({"round": rnd, "format": "conventional", "completed": False})
        rnd += 1
    for _ in range(n_sprint):
        events.append({"round": rnd, "format": "sprint_qualifying", "completed": False})
        rnd += 1
    return events


def test_close_title_fight_multiple_drivers_can_still_win(monkeypatch):
    # Leader has 400, 2 conventional rounds left = 52 max points on offer.
    # Norris (350) could reach 402 > 400 -> can still win.
    # Leclerc (200) could reach 252 < 400 -> cannot.
    monkeypatch.setattr(svc, "get_drivers", lambda year: _drivers())
    monkeypatch.setattr(svc, "get_schedule", lambda year: _remaining_events(n_conventional=2))

    out = svc.get_wdc_calculator(2024)
    by_id = {d["driverId"]: d for d in out["drivers"]}

    assert out["roundsRemaining"] == 2
    assert out["maxRemainingPoints"] == 2 * 26
    assert by_id["verstappen"]["canWin"] is True
    assert by_id["norris"]["canWin"] is True
    assert by_id["leclerc"]["canWin"] is False
    assert out["decided"] is False


def test_season_over_only_leader_can_win(monkeypatch):
    # No rounds left at all -> nothing changes, title is decided.
    monkeypatch.setattr(svc, "get_drivers", lambda year: _drivers())
    monkeypatch.setattr(svc, "get_schedule", lambda year: _remaining_events(completed_conventional=24))

    out = svc.get_wdc_calculator(2024)
    assert out["roundsRemaining"] == 0
    assert out["maxRemainingPoints"] == 0
    assert out["decided"] is True
    by_id = {d["driverId"]: d for d in out["drivers"]}
    assert by_id["verstappen"]["canWin"] is True
    assert by_id["norris"]["canWin"] is False


def test_sprint_weekends_add_sprint_points_on_top(monkeypatch):
    monkeypatch.setattr(svc, "get_drivers", lambda year: _drivers())
    monkeypatch.setattr(svc, "get_schedule", lambda year: _remaining_events(n_sprint=1))

    out = svc.get_wdc_calculator(2024)
    assert out["sprintRoundsRemaining"] == 1
    assert out["maxRemainingPoints"] == 8 + 25 + 1


def test_driver_with_no_points_on_record_does_not_crash(monkeypatch):
    drivers = _drivers()
    drivers.append({"driverId": "rookie", "givenName": "New", "familyName": "Driver", "code": "NEW",
                     "position": None, "points": None, "teamName": "Red Bull", "teamId": "red_bull",
                     "teamLogoUrl": None, "teamColor": None, "headshotUrl": None})
    monkeypatch.setattr(svc, "get_drivers", lambda year: drivers)
    monkeypatch.setattr(svc, "get_schedule", lambda year: _remaining_events(n_conventional=1))

    out = svc.get_wdc_calculator(2024)
    by_id = {d["driverId"]: d for d in out["drivers"]}
    assert by_id["rookie"]["points"] == 0
    assert by_id["rookie"]["canWin"] is False
    # A driver with no `position` sorts to the back rather than crashing/erroring.
    assert out["drivers"][-1]["driverId"] == "rookie"


def test_no_standings_returns_empty_but_valid_payload(monkeypatch):
    monkeypatch.setattr(svc, "get_drivers", lambda year: [])
    monkeypatch.setattr(svc, "get_schedule", lambda year: [])

    out = svc.get_wdc_calculator(2024)
    assert out["drivers"] == []
    assert out["decided"] is True


if __name__ == "__main__":
    import sys
    import pytest
    sys.exit(pytest.main([__file__, "-v"]))
