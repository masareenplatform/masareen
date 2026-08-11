"""Unit tests for the forecast service (real trend engine + mocked session)."""
from unittest.mock import AsyncMock, MagicMock
import pytest

from src.domain.forecast import linear_trend, linear_forecast, next_quarter_impact
from src.infrastructure.forecast_repository import ForecastRepository


# ── Pure engine (no DB) ──────────────────────────────────────────────
def test_linear_trend_flat():
    slope, intercept = linear_trend([5.0, 5.0, 5.0])
    assert slope == 0.0
    assert intercept == 5.0


def test_linear_trend_upward():
    slope, intercept = linear_trend([1.0, 2.0, 3.0])
    assert slope == pytest.approx(1.0)
    assert intercept == pytest.approx(1.0)


def test_linear_forecast_projection():
    # history 1,2,3 → slope 1, intercept 1; next 3 months = 4,5,6
    out = linear_forecast([1.0, 2.0, 3.0], periods=3)
    assert out == [4.0, 5.0, 6.0]


def test_linear_forecast_floors_negatives():
    # declining series can project negative; floored at 0
    out = linear_forecast([3.0, 2.0, 1.0], periods=2)
    assert all(v >= 0.0 for v in out)


def test_linear_forecast_empty():
    # No history → honest flat-zero projection (not fabricated growth).
    assert linear_forecast([], periods=3) == [0.0, 0.0, 0.0]


def test_next_quarter_impact_sums():
    assert next_quarter_impact([1.0, 2.0, 3.0], periods=3) == 15.0


# ── Repository (mocked async session) ──────────────────────────────────
@pytest.mark.asyncio
async def test_monthly_series_returns_history(mock_session):
    repo = ForecastRepository(mock_session)
    res = MagicMock()
    res.mappings.return_value.all.return_value = [
        {"total": 10.0}, {"total": 20.0}, {"total": 30.0},
    ]
    mock_session.execute.return_value = res
    series = await repo.monthly_impact_value_series(months=12)
    assert series == [10.0, 20.0, 30.0]


@pytest.mark.asyncio
async def test_forecast_impact_builds_projection(mock_session):
    repo = ForecastRepository(mock_session)
    res = MagicMock()
    res.mappings.return_value.all.return_value = [
        {"total": 1.0}, {"total": 2.0}, {"total": 3.0},
    ]
    mock_session.execute.return_value = res
    out = await repo.forecast_impact(months=12, periods=3)
    assert out["history"] == [1.0, 2.0, 3.0]
    assert out["projected"] == [4.0, 5.0, 6.0]
    assert "series_id" in out
