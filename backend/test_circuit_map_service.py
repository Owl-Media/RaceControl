"""
Offline tests for the circuit outline endpoint (`fastf1_service.get_circuit_map`).

Regression coverage for a real bug: the track outline was drawn as a jagged
polygon on some circuits (Hungaroring, reported by a user) while others
(Albert Park) looked fine. Root cause: `lap.get_telemetry()` merges the
low-frequency (~3.7Hz) position channel onto the much higher-frequency car
channel, holding each position sample across many rows until the next real
update. The old code downsampled by taking every Nth *row* (uniform in
time), which over-samples those held/duplicate stretches — worse on tracks
with more slow corners, where the car dwells at nearly the same X/Y for
longer — and under-samples the transitions between them, drawing straight
edges through what should be curves.

The fix resamples at fixed steps of *distance* along the lap instead, which
this test verifies produces evenly spaced points regardless of how lopsided
the time-domain sampling was.

    python test_circuit_map_service.py     (or: pytest test_circuit_map_service.py)
"""

from types import SimpleNamespace

import numpy as np
import pandas as pd

import fastf1_service as svc


class _FakeLap:
    def __init__(self, tel: pd.DataFrame, driver="VER"):
        self._tel = tel
        self._driver = driver

    def get_telemetry(self):
        return self._tel

    def get(self, key, default=None):
        return {"Driver": self._driver}.get(key, default)

    def __getitem__(self, key):
        return {"Driver": self._driver}[key]


class _FakeLaps:
    def __init__(self, lap: _FakeLap):
        self._lap = lap

    def __len__(self):
        return 1

    def pick_fastest(self):
        return self._lap


def _staircase_telemetry():
    """A lap that spends many held/duplicate samples in a slow corner (X~0)
    then jumps through a fast, sparsely-time-sampled straight (X 0->1000)."""
    xs, ys, dists = [], [], []
    d = 0.0
    # Slow corner: 200 near-duplicate samples clustered at (0, 0), distance
    # barely advancing between them (this is the "held" stretch).
    for i in range(200):
        xs.append(0.0 + (0.01 if i % 2 else 0.0))
        ys.append(0.0)
        d += 0.05
        dists.append(d)
    # Fast straight: only 5 samples cover a 1000-unit jump.
    for i in range(1, 6):
        xs.append(i * 200.0)
        ys.append(0.0)
        d += 200.0
        dists.append(d)
    n = len(xs)
    return pd.DataFrame({
        "X": xs,
        "Y": ys,
        "Z": [0.0] * n,
        "Speed": [50.0] * 200 + [300.0] * 5,
        "DRS": [0] * n,
        "Distance": dists,
    })


def _stub_session(tel):
    lap = _FakeLap(tel)
    laps = _FakeLaps(lap)
    session = SimpleNamespace(
        event={"EventName": "Test Grand Prix", "Location": "Testville", "Country": "Testland"},
        laps=laps,
        get_driver=lambda abbr: {"FullName": "Max Verstappen", "TeamName": "Red Bull Racing", "TeamColor": "3671C6"},
        get_circuit_info=lambda: SimpleNamespace(rotation=0.0, corners=pd.DataFrame(columns=["Number", "Letter"])),
    )
    return session


def test_outline_resampled_by_distance_not_time_row(monkeypatch):
    tel = _staircase_telemetry()
    session = _stub_session(tel)
    monkeypatch.setattr(svc, "_load_session", lambda *a, **k: session)

    out = svc.get_circuit_map(2024, 1)
    outline = out["outline"]
    assert len(outline) == 350

    xs = np.array([p["x"] for p in outline])
    # The old row-uniform downsample would put the vast majority of the 350
    # points inside the held cluster near x=0 (since 200 of 205 raw rows
    # live there) and almost none across the 0->1000 jump. Distance-uniform
    # resampling should instead spread points across the full x range.
    assert xs.max() > 900  # actually reaches near the far end
    # At least a meaningful fraction of points should lie in the "straight"
    # half of the track (x > 500), which the old algorithm would essentially
    # skip entirely.
    assert (xs > 500).sum() > 50


def test_empty_session_returns_empty_outline(monkeypatch):
    laps = SimpleNamespace(__len__=lambda self=None: 0)

    class _EmptyLaps:
        def __len__(self):
            return 0

    session = SimpleNamespace(
        event={"EventName": "Test Grand Prix", "Location": "Testville", "Country": "Testland"},
        laps=_EmptyLaps(),
    )
    monkeypatch.setattr(svc, "_load_session", lambda *a, **k: session)

    out = svc.get_circuit_map(2024, 1)
    assert out["outline"] == []
    assert out["points"] == []


if __name__ == "__main__":
    import sys
    import pytest
    sys.exit(pytest.main([__file__, "-v"]))
