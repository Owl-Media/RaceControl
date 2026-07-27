"""
Offline tests for the hardcoded team-logo mapping (`_team_logo_url`) and its
use in the driver/constructor standings and teams endpoints.

Neither FastF1 nor Ergast/Jolpica expose team logos, so `_team_logo_url`
looks up a manually maintained teamId -> F1.com-slug table and builds a URL
against F1's own media CDN. These tests pin the contract other code relies
on: known teamIds resolve to a URL, unknown/missing teamIds resolve to None
rather than raising or building a garbage URL.

    python test_team_logo.py     (or: pytest test_team_logo.py)
"""

import fastf1_service as svc


def test_known_team_id_resolves_to_a_logo_url():
    url = svc._team_logo_url("red_bull")
    assert url is not None
    assert url.startswith("https://media.formula1.com/")
    assert "redbullracing" in url


def test_unknown_team_id_returns_none():
    assert svc._team_logo_url("not_a_real_team") is None


def test_none_team_id_returns_none():
    assert svc._team_logo_url(None) is None


def test_driver_standings_include_team_logo_url(monkeypatch):
    class _Resp:
        content = [__import__("pandas").DataFrame([
            {
                "position": 1, "points": 100, "wins": 3,
                "driverId": "verstappen", "driverNumber": "1", "driverCode": "VER",
                "givenName": "Max", "familyName": "Verstappen", "driverNationality": "Dutch",
                "dateOfBirth": "1997-09-30",
                "constructorNames": ["Red Bull"], "constructorIds": ["red_bull"],
            }
        ])]

    monkeypatch.setattr(svc._ergast, "get_driver_standings", lambda season, limit: _Resp())
    out = svc.get_driver_standings(2024)
    assert out[0]["teamLogoUrl"] is not None
    assert "redbullracing" in out[0]["teamLogoUrl"]


def test_constructor_standings_include_team_logo_url(monkeypatch):
    class _Resp:
        content = [__import__("pandas").DataFrame([
            {"position": 1, "points": 500, "wins": 10, "constructorId": "ferrari",
             "constructorName": "Ferrari", "constructorNationality": "Italian"},
        ])]

    monkeypatch.setattr(svc._ergast, "get_constructor_standings", lambda season, limit: _Resp())
    out = svc.get_constructor_standings(2024)
    assert out[0]["teamLogoUrl"] is not None
    assert "ferrari" in out[0]["teamLogoUrl"]


if __name__ == "__main__":
    import sys
    import pytest
    sys.exit(pytest.main([__file__, "-v"]))
