"""Forecast engine, real, deterministic time-series projection.

No ML/LLM magic: given a series of historical monthly impact values we
fit a simple ordinary-least-squares linear trend and project it forward.
This is honest, explainable, and fully unit-testable. A production build
can swap this for an ARIMA/Prophet model behind the same interface.
"""
from __future__ import annotations

from typing import List


def linear_trend(history: List[float]) -> tuple[float, float]:
    """Return (slope, intercept) of the OLS line fit to ``history``.

    ``history[i]`` is the value at month ``i`` (0-based, evenly spaced).
    """
    n = len(history)
    if n == 0:
        return (0.0, 0.0)
    if n == 1:
        # No trend observable: flat line at the single observed value.
        return (0.0, float(history[0]))
    xs = list(range(n))
    mean_x = sum(xs) / n
    mean_y = sum(history) / n
    num = sum((x - mean_x) * (y - mean_y) for x, y in zip(xs, history))
    den = sum((x - mean_x) ** 2 for x in xs)
    slope = (num / den) if den != 0 else 0.0
    intercept = mean_y - slope * mean_x
    return (slope, intercept)


def linear_forecast(history: List[float], periods: int = 3) -> List[float]:
    """Project ``periods`` future months beyond the observed history.

    Returns one value per future month. Negative projections are floored at 0
    (impact value cannot be negative).
    """
    if periods <= 0:
        return []
    slope, intercept = linear_trend(history)
    n = len(history)
    out: List[float] = []
    for k in range(1, periods + 1):
        value = slope * (n - 1 + k) + intercept
        out.append(max(0.0, round(value, 2)))
    return out


def next_quarter_impact(history: List[float], periods: int = 3) -> float:
    """Sum of the projected next ``periods`` months (a forward-looking total)."""
    return round(sum(linear_forecast(history, periods)), 2)
