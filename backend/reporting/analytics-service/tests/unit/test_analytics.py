import pytest
from unittest.mock import AsyncMock, MagicMock

from src.infrastructure.postgres_repository import AnalyticsRepository


class _Mappings:
    def __init__(self, row, rows):
        self._row = row
        self._rows = rows if rows is not None else []

    def first(self):
        return self._row

    def __iter__(self):
        return iter(self._rows)


def _result(row=None, rows=None):
    res = MagicMock()
    res.mappings.return_value = _Mappings(row, rows)
    return res


@pytest.mark.asyncio
async def test_platform_summary_real_rows(mock_session):
    repo = AnalyticsRepository(mock_session)
    res1 = _result({
        "total_users": 10, "active_programs": 3, "verified_tasks": 5,
        "impact_assets_created": 2, "countries_active": 1,
    })
    res2 = _result(rows=[{"sdg": 1}, {"sdg": 7}])

    mock_session.execute.side_effect = [res1, res2]

    d = await repo.platform_summary()

    assert d["total_users"] == 10
    assert d["active_programs"] == 3
    assert d["sdgs_touched"] == [1, 7]
    assert d["total_economic_value_usd"] == 0.0


@pytest.mark.asyncio
async def test_program_stats_found_false(mock_session):
    repo = AnalyticsRepository(mock_session)
    mock_session.execute.return_value = _result(row=None)

    d = await repo.program_stats("p1")

    assert d["found"] is False
    assert d["enrolled"] == 0


@pytest.mark.asyncio
async def test_program_stats_found_true(mock_session):
    repo = AnalyticsRepository(mock_session)
    mock_session.execute.return_value = _result({
        "enrolled": 4, "completed_tasks": 2, "verified_evidence": 1,
    })

    d = await repo.program_stats("p1")

    assert d["found"] is True
    assert d["enrolled"] == 4


@pytest.mark.asyncio
async def test_org_stats_found_false(mock_session):
    repo = AnalyticsRepository(mock_session)
    mock_session.execute.return_value = _result(row=None)

    d = await repo.org_stats("o1")

    assert d["found"] is False
    assert d["active_programs"] == 0
    assert d["total_volunteers"] == 0
    assert d["oii_score"] == 0.0
    assert d["verified_outcomes"] == 0


@pytest.mark.asyncio
async def test_org_stats_found_true(mock_session):
    repo = AnalyticsRepository(mock_session)
    mock_session.execute.return_value = _result({
        "active_programs": 2, "total_volunteers": 7,
        "oii_score": 0.85, "verified_outcomes": 3,
    })

    d = await repo.org_stats("o1")

    assert d["found"] is True
    assert d["active_programs"] == 2
    assert d["total_volunteers"] == 7
    assert d["oii_score"] == 0.85
    assert d["verified_outcomes"] == 3


@pytest.mark.asyncio
async def test_user_stats_found_false(mock_session):
    repo = AnalyticsRepository(mock_session)
    mock_session.execute.return_value = _result(row=None)

    d = await repo.user_stats("u1")

    assert d["found"] is False
    assert d["tasks_completed"] == 0
    assert d["programs_joined"] == 0
    assert d["impact_assets"] == 0
    assert d["pms_score"] == 0.0


@pytest.mark.asyncio
async def test_user_stats_found_true(mock_session):
    repo = AnalyticsRepository(mock_session)
    mock_session.execute.return_value = _result({
        "tasks_completed": 9, "programs_joined": 2,
        "impact_assets": 4, "pms_score": 0.73,
    })

    d = await repo.user_stats("u1")

    assert d["found"] is True
    assert d["tasks_completed"] == 9
    assert d["programs_joined"] == 2
    assert d["impact_assets"] == 4
    assert d["pms_score"] == 0.73


@pytest.mark.asyncio
async def test_sdg_progress_initializes_all_17(mock_session):
    repo = AnalyticsRepository(mock_session)
    mock_session.execute.return_value = _result(rows=[])

    d = await repo.sdg_progress()

    assert len(d) == 17
    assert all(v == 0 for v in d.values())
    assert [f"sdg_{i}" for i in range(1, 18)] == list(d.keys())


@pytest.mark.asyncio
async def test_sdg_progress_fills_counts(mock_session):
    repo = AnalyticsRepository(mock_session)
    mock_session.execute.return_value = _result(rows=[
        {"sdg": 1, "c": 3}, {"sdg": 5, "c": 2},
    ])

    d = await repo.sdg_progress()

    assert d["sdg_1"] == 3
    assert d["sdg_5"] == 2
    assert d["sdg_2"] == 0
