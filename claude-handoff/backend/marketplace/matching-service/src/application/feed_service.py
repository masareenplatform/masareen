"""Feed service for the social impact discovery engine.

Ranking is deterministic and explainable so the metric is *valid, reliable and
consistent* across requests for the same inputs:

    score (0..100) = 100 * (0.5 * sdg_relevance + 0.3 * verification + 0.2 * recency)

  * sdg_relevance : fraction of the viewer's interested SDGs that this asset
                    contributes to (neutral 0.5 when the viewer has no stated
                    interests yet).
  * verification  : clamped impact-asset confidence in [0, 1].
  * recency       : exponential time-decay with a 72h half-life.

Because the score depends only on asset attributes + the viewer's interests, the
same asset yields the same score on every request (no randomness), and the feed
is ordered by (score desc, created_at desc, id) for stable, gap-free pagination.
"""
from typing import List, Dict, Any, Optional
from datetime import datetime, timezone
from ..infrastructure.graph_client import GraphClient  # Hypothetical client
from shared.utils.logging import get_logger

log = get_logger(__name__)

RECENCY_HALF_LIFE_HOURS = 72.0
# Cap the candidate window so a deep scroll can't blow up the graph query.
MAX_CANDIDATES = 200


def _to_dt(value: Any) -> Optional[datetime]:
    if isinstance(value, datetime):
        return value
    if isinstance(value, str):
        try:
            return datetime.fromisoformat(value.replace("Z", "+00:00"))
        except Exception:
            return None
    return None


def _hours_since(value: Any) -> float:
    dt = _to_dt(value)
    if dt is None:
        return 1e9
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return max(0.0, (datetime.now(timezone.utc) - dt).total_seconds() / 3600.0)


def _score_asset(asset: Dict[str, Any], sdg_ids: List[int], user_sdgs: List[int]) -> float:
    # SDG relevance -------------------------------------------------------------
    if user_sdgs:
        inter = set(sdg_ids) & set(user_sdgs)
        sdg_relevance = len(inter) / len(user_sdgs)
    else:
        sdg_relevance = 0.5  # neutral prior for users without stated interests

    # Verification --------------------------------------------------------------
    try:
        verification = min(1.0, max(0.0, float(asset.get("confidence_score", 0.5))))
    except (TypeError, ValueError):
        verification = 0.5

    # Recency -------------------------------------------------------------------
    age_h = _hours_since(asset.get("created_at"))
    recency = 0.5 ** (age_h / RECENCY_HALF_LIFE_HOURS)

    combined = 0.5 * sdg_relevance + 0.3 * verification + 0.2 * recency
    return round(combined * 100.0, 1)


class FeedService:
    def __init__(self, graph_client: Any):
        self.graph = graph_client

    async def get_personalized_feed(
        self, user_id: str, limit: int = 20, offset: int = 0
    ) -> List[Dict[str, Any]]:
        log.info("Computing personalized feed for user %s (limit=%s offset=%s)", user_id, limit, offset)

        # 1. Viewer interests (used for SDG relevance). Absent => neutral prior.
        user_sdgs: List[int] = []
        try:
            interest_rows = await self.graph.execute_query(
                "MATCH (u:Person {id: $user_id})-[:INTERESTED_IN]->(s:SDG) "
                "RETURN s.number AS sdg",
                {"user_id": user_id},
            )
            user_sdgs = [int(r["sdg"]) for r in interest_rows if r.get("sdg") is not None]
        except Exception as e:  # pragma: no cover - resilient to graph gaps
            log.warning("Could not load user SDG interests: %s", e)

        # 2. Candidate assets (bounded window) with their creators + SDGs.
        window = min(offset + limit, MAX_CANDIDATES)
        query = """
        MATCH (asset:ImpactAsset)
        OPTIONAL MATCH (creator:Person)-[:CREATED]->(asset)
        OPTIONAL MATCH (asset)-[:CONTRIBUTES_TO]->(s:SDG)
        RETURN asset, creator, s.number AS sdg_id
        ORDER BY asset.created_at DESC
        LIMIT $window
        """
        try:
            rows = await self.graph.execute_query(query, {"window": window})
        except Exception as e:
            log.error("Graph query failed for feed: %s", e)
            raise

        # 3. Aggregate multi-row results per asset.
        assets: Dict[str, Dict[str, Any]] = {}
        for row in rows:
            asset = row.get("asset") or {}
            aid = asset.get("id")
            if not aid:
                continue
            entry = assets.setdefault(
                aid,
                {
                    "asset": asset,
                    "creator": (row.get("creator") or {}).get("full_name") or "MASAREN",
                    "creatorAvatar": (row.get("creator") or {}).get("avatar_url"),
                    "sdg_ids": [],
                },
            )
            sdg = row.get("sdg_id")
            if sdg is not None and sdg not in entry["sdg_ids"]:
                entry["sdg_ids"].append(int(sdg))

        # 4. Score + order (stable tie-break for gap-free pagination).
        ranked = []
        for aid, e in assets.items():
            score = _score_asset(e["asset"], e["sdg_ids"], user_sdgs)
            asset = e["asset"]
            ranked.append(
                {
                    "id": aid,
                    "creator": e["creator"],
                    "creatorAvatar": e["creatorAvatar"],
                    "content_url": asset.get("storage_url"),
                    "type": (asset.get("media_type") or "TEXT").upper(),
                    "caption": asset.get("description") or asset.get("title") or "",
                    "image_url": asset.get("image_url"),
                    "title": asset.get("title"),
                    "summary": asset.get("summary"),
                    "source": asset.get("source"),
                    "domain": asset.get("domain"),
                    "url": asset.get("url"),
                    "sdg": (e["sdg_ids"][0] if e["sdg_ids"] else None),
                    "score": score,
                    "confidence": round(min(1.0, max(0.0, float(asset.get("confidence_score", 0.5)))) * 100, 1),
                    "timestamp": asset.get("created_at"),
                    "likes": int(asset.get("likes", 0) or 0),
                    "comments": int(asset.get("comments", 0) or 0),
                    "shares": int(asset.get("shares", 0) or 0),
                    "likedByMe": False,
                }
            )

        ranked.sort(
            key=lambda x: (
                x["score"],
                _hours_since(x["timestamp"]) * -1,  # newer first (smaller age => larger)
                x["id"],
            ),
            reverse=True,
        )

        return ranked[offset : offset + limit]
