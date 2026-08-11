"""Unit tests for FeedService — personalized impact feed ranking."""
import pytest
from unittest.mock import AsyncMock, MagicMock

from src.application.feed_service import FeedService


@pytest.mark.asyncio
async def test_feed_ranks_by_score_desc():
    assets = [
        {"asset": {"id": "a1", "confidence_score": 0.2, "storage_url": "u1", "media_type": "VIDEO", "created_at": "2020-01-01T00:00:00Z"},
         "creator": {"full_name": "Bob"}, "sdg_id": 3},
        {"asset": {"id": "a2", "confidence_score": 0.9, "storage_url": "u2", "media_type": "PHOTO", "created_at": "2020-01-02T00:00:00Z"},
         "creator": {"full_name": "Amy"}, "sdg_id": 1},
    ]
    fake_graph = MagicMock()
    # First call = user SDG interests, second call = candidate assets.
    fake_graph.execute_query = AsyncMock(side_effect=[[{"sdg": 3}, {"sdg": 1}], assets])

    feed = await FeedService(fake_graph).get_personalized_feed("user-1")
    assert feed[0]["post_id"] == "a2"
    assert feed[0]["score"] > feed[1]["score"]
    assert 0 < feed[0]["score"] <= 100
    assert feed[0]["creator"] == "Amy"
    assert feed[0]["type"] == "PHOTO"
    assert feed[0]["sdg"] == 1


@pytest.mark.asyncio
async def test_feed_score_is_deterministic():
    assets = [
        {"asset": {"id": "a1", "confidence_score": 0.6, "storage_url": "u1", "media_type": "IMAGE", "created_at": "2020-01-01T00:00:00Z"},
         "creator": {"full_name": "Bob"}, "sdg_id": 3},
    ]
    fake_graph = MagicMock()
    fake_graph.execute_query = AsyncMock(side_effect=[[{"sdg": 3}], assets])

    f1 = await FeedService(fake_graph).get_personalized_feed("u")
    # Same inputs -> identical score (no randomness).
    fake_graph.execute_query = AsyncMock(side_effect=[[{"sdg": 3}], assets])
    f2 = await FeedService(fake_graph).get_personalized_feed("u")
    assert f1[0]["score"] == f2[0]["score"]


@pytest.mark.asyncio
async def test_feed_empty():
    fake_graph = MagicMock()
    fake_graph.execute_query = AsyncMock(return_value=[])
    feed = await FeedService(fake_graph).get_personalized_feed("u")
    assert feed == []


@pytest.mark.asyncio
async def test_feed_default_confidence_is_bounded():
    fake_graph = MagicMock()
    fake_graph.execute_query = AsyncMock(side_effect=[
        [],  # no stated interests -> neutral prior
        [{"asset": {"id": "a3", "storage_url": "u", "media_type": "TEXT", "created_at": "2020-01-01T00:00:00Z"},
          "creator": {"full_name": "C"}, "sdg_id": 2}],
    ])
    feed = await FeedService(fake_graph).get_personalized_feed("u")
    assert 0 <= feed[0]["score"] <= 100


@pytest.mark.asyncio
async def test_feed_passes_window_param():
    fake_graph = MagicMock()
    fake_graph.execute_query = AsyncMock(side_effect=[[], []])
    await FeedService(fake_graph).get_personalized_feed("u9", limit=5, offset=2)
    # Second call is the candidate-asset query, sized to the bounded window.
    asset_call = fake_graph.execute_query.call_args_list[1]
    assert asset_call[0][1] == {"window": 7}
    # First call loads the viewer's SDG interests.
    assert fake_graph.execute_query.call_args_list[0][0][1] == {"user_id": "u9"}
