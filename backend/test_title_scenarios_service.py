import analytics_service as analytics
import fastf1_service as svc


def _calculator(rounds=1):
    return {
        "roundsRemaining": rounds,
        "drivers": [
            {"driverId": "norris", "driverCode": "NOR", "teamColor": "#FF8700", "points": 400},
            {"driverId": "piastri", "driverCode": "PIA", "teamColor": "#FF8700", "points": 393},
        ],
    }


def test_missing_contenders_returns_available_false(monkeypatch):
    monkeypatch.setattr(svc, "get_wdc_calculator", lambda _year: {"roundsRemaining": 0, "drivers": []})
    out = analytics.get_title_scenarios(2026)
    assert out["available"] is False
    assert out["cells"] == []


def test_permutation_points_and_outcome_are_correct(monkeypatch):
    monkeypatch.setattr(svc, "get_wdc_calculator", lambda _year: _calculator())
    out = analytics.get_title_scenarios(2026)
    cell = next(
        item for item in out["cells"]
        if item["d1Position"] == 2 and item["d2Position"] == 1
    )
    assert cell["d1Points"] == 418
    assert cell["d2Points"] == 418
    assert cell["margin"] == 0
    assert cell["outcome"] == "TIED"


def test_final_round_lead_clinches_title(monkeypatch):
    monkeypatch.setattr(svc, "get_wdc_calculator", lambda _year: _calculator(rounds=1))
    out = analytics.get_title_scenarios(2026)
    cell = next(
        item for item in out["cells"]
        if item["d1Position"] == 1 and item["d2Position"] == 2
    )
    assert cell["outcome"] == "D1_CLINCHED"


def test_percentile_direction_is_respected():
    population = [1.0, 2.0, 3.0, 4.0]
    assert analytics._percentile(4.0, population, True) == 100
    assert analytics._percentile(1.0, population, False) == 100
