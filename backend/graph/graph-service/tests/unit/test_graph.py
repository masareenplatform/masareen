"""Unit tests for the MASAREEN graph-service (no live Neo4j required)."""
import sys
import os

# Make the ``src`` package importable when running from the backend root.
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from unittest.mock import AsyncMock, MagicMock

import pytest

from src.schemas.nodes import NodeLabel, RelationshipType
from src.infrastructure.neo4j_client import GraphRepository
from src.queries.person_queries import (
    GET_PERSON_IMPACT_NETWORK,
    MATCH_PERSON_TO_OPPORTUNITIES,
)


def _build_fake_driver(row_result):
    """Build a fake neo4j driver whose session.execute_read returns row_result."""
    fake_tx = MagicMock()
    fake_tx.run = AsyncMock(return_value=MagicMock(data=AsyncMock(return_value=row_result)))

    fake_session = MagicMock()
    async def _execute_read(fn):
        return await fn(fake_tx)

    fake_session.execute_read = AsyncMock(side_effect=_execute_read)

    cm = AsyncMock()
    cm.__aenter__.return_value = fake_session
    cm.__aexit__.return_value = False

    fake_driver = MagicMock()
    fake_driver.session = MagicMock(return_value=cm)
    return fake_driver


@pytest.mark.asyncio
async def test_node_labels_have_expected_values():
    assert NodeLabel.PERSON.value == "Person"
    assert NodeLabel.IMPACT_ASSET.value == "ImpactAsset"
    assert NodeLabel.SDG.value == "SDG"


@pytest.mark.asyncio
async def test_relationship_types():
    assert RelationshipType.GENERATED.value == "GENERATED"
    assert RelationshipType.MATCHED_TO.value == "MATCHED_TO"
    assert RelationshipType.CONTRIBUTES_TO.value == "CONTRIBUTES_TO"


@pytest.mark.asyncio
async def test_query_constants_reference_labels():
    assert "ImpactAsset" in GET_PERSON_IMPACT_NETWORK
    assert "Person" in GET_PERSON_IMPACT_NETWORK
    assert (
        "OPPORTUNITIES" in MATCH_PERSON_TO_OPPORTUNITIES.upper()
        or "Opportunity" in MATCH_PERSON_TO_OPPORTUNITIES
    )


@pytest.mark.asyncio
async def test_get_impact_network_reshapes():
    row = {
        "tasks": [{"id": "t1"}],
        "programs": [{"id": "prog1"}],
        "sdgs": [{"id": "sdg1"}],
        "skills": [{"id": "s1"}],
        "impact_assets": [{"id": "ia1"}],
    }
    driver = _build_fake_driver([row])
    repo = GraphRepository(driver)
    out = await repo.get_impact_network("p1")

    assert out["person_id"] == "p1"
    assert isinstance(out["tasks"], list)
    assert isinstance(out["impact_assets"], list)
    assert out["tasks"][0] == {"id": "t1"}
    assert out["impact_assets"][0] == {"id": "ia1"}
    assert isinstance(out["tasks"][0], dict)
    assert isinstance(out["impact_assets"][0], dict)


@pytest.mark.asyncio
async def test_talent_match_reshapes():
    rows = [
        {"o": {"id": "o1"}, "skill_overlap": 3},
        {"o": {"id": "o2"}, "skill_overlap": 1},
    ]
    driver = _build_fake_driver(rows)
    repo = GraphRepository(driver)
    out = await repo.talent_match("p1", 5)

    assert out == rows
    assert isinstance(out, list)
    assert isinstance(out[0], dict)


@pytest.mark.asyncio
async def test_unavailable_raises():
    repo2 = GraphRepository(MagicMock())
    repo2._driver = None
    with pytest.raises(RuntimeError):
        await repo2.get_impact_network("x")
