"""Unit tests for the portfolio service pure logic and SQL aggregation.

The endpoints hit PostgreSQL directly, so we inject a mocked async session that
returns canned rows — no external service required. The `_tier` mapping and the
real aggregation math are tested directly.
"""
from unittest.mock import AsyncMock, MagicMock

import pytest

from src.api import _tier, TIER_BY_SCORE, PortfolioSummary, ImpactAssetResponse


def test_tier_mapping_boundaries():
    # Above-or-equal each threshold returns the associated tier.
    assert _tier(0.90) == "DIAMOND"
    assert _tier(0.85) == "DIAMOND"
    assert _tier(0.70) == "PLATINUM"
    assert _tier(0.55) == "GOLD"
    assert _tier(0.40) == "SILVER"
    assert _tier(0.25) == "BRONZE_LOW"
    assert _tier(0.0) == "BRONZE"
    assert _tier(-0.1) == "BRONZE"


def test_tier_in_between_thresholds():
    # 0.60 falls between GOLD(0.55) and PLATINUM(0.70) -> GOLD
    assert _tier(0.60) == "GOLD"
    # 0.30 -> BRONZE_LOW
    assert _tier(0.30) == "BRONZE_LOW"


def test_portfolio_summary_defaults_are_honest_zeros():
    s = PortfolioSummary(user_id="u1")
    assert s.total_assets == 0
    assert s.total_value_usd == 0.0
    assert s.pms_score == 0.0
    assert s.pms_tier == "BRONZE"
    assert s.sdg_coverage == []
    assert s.top_skills == []


def test_impact_asset_response_optional_fields():
    a = ImpactAssetResponse(id="a1")
    assert a.title is None
    assert a.economic_value_usd == 0.0
    assert a.sdg_tags == []


@pytest.mark.asyncio
async def test_get_portfolio_aggregates_real_rows(mock_session):
    from src.api import get_portfolio

    # Build fake result rows. The endpoints access both by index (pms_row[0])
    # and by attribute (a.economic_value_usd), so support both.
    class _Row:
        def __init__(self, **kwargs):
            self.__dict__.update(kwargs)

        def __getitem__(self, key):
            if isinstance(key, int):
                # SQLAlchemy mapping rows index into the value tuple.
                return list(self.__dict__.values())[key]
            return self.__dict__[key]

    completed = MagicMock(); completed.scalar.return_value = 7
    programs = MagicMock(); programs.scalar.return_value = 2
    certs = MagicMock(); certs.scalar.return_value = 1
    pms = _Row(**{"0": 0.82, "1": None})
    asset_rows = [
        _Row(id="a1", title="Solar Kit", asset_type="ImpactAsset",
              economic_value_usd=1200.5, sdg_tags=[1, 7], impact_category="Energy",
              impact_magnitude="HIGH", created_at="2024-01-01"),
        _Row(id="a2", title="Well", asset_type="ImpactAsset",
              economic_value_usd=800.0, sdg_tags=[6], impact_category="Water",
              impact_magnitude="MED", created_at="2024-02-01"),
    ]
    skills = _Row(**{"0": "Carpentry"})

    mock_session.execute = AsyncMock()
    # execute returns different fakes per call; order matches get_portfolio SQL.
    mock_session.execute.side_effect = [
        completed, programs, certs,
        MagicMock(fetchone=MagicMock(return_value=pms)),
        MagicMock(fetchall=MagicMock(return_value=asset_rows)),
        MagicMock(fetchall=MagicMock(return_value=[skills])),
    ]

    resp = await get_portfolio("user-abc", session=mock_session)
    data = resp.data
    assert isinstance(data, PortfolioSummary)
    assert data.user_id == "user-abc"
    assert data.completed_tasks == 7
    assert data.programs_participated == 2
    assert data.certificates_count == 1
    assert data.total_assets == 2
    assert data.total_value_usd == 2000.5
    assert data.pms_score == 0.82
    assert data.pms_tier == "PLATINUM"
    assert data.sdg_coverage == [1, 6, 7]
    assert data.top_skills == ["Carpentry"]


@pytest.mark.asyncio
async def test_get_portfolio_empty_user_returns_zeros(mock_session):
    from src.api import get_portfolio
    from fastapi import HTTPException

    completed = MagicMock(); completed.scalar.return_value = 0
    programs = MagicMock(); programs.scalar.return_value = 0
    certs = MagicMock(); certs.scalar.return_value = 0
    pms = None  # no pms row

    class _Row:
        def __init__(self, **kwargs):
            self.__dict__.update(kwargs)

        def __getitem__(self, key):
            return self.__dict__[key]
    mock_session.execute = AsyncMock()
    mock_session.execute.side_effect = [
        completed, programs, certs,
        MagicMock(fetchone=MagicMock(return_value=pms)),
        MagicMock(fetchall=MagicMock(return_value=[])),
        MagicMock(fetchall=MagicMock(return_value=[])),
    ]

    resp = await get_portfolio("ghost", session=mock_session)
    assert resp.data.completed_tasks == 0
    assert resp.data.pms_score == 0.0
    assert resp.data.pms_tier == "BRONZE"
