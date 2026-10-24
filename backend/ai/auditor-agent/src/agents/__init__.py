"""
Graph Synthesis Engine, executes structural inferences into the local Neo4j
knowledge graph and adjusts Proof of Mission Scores (PMS) across 10 dimensions.

This agent is the bridge between cloud AI reasoning and local graph state.
The cloud LLM produces PMS dimension deltas; this agent applies them via
raw Cypher insertions into the local Neo4j instance.

Pattern:
  1. Consume ImpactAssetCreated event
  2. Fetch current graph neighbourhood from Neo4j (local)
  3. Send graph context to cloud LLM for PMS dimension reasoning
  4. Apply returned Cypher mutations to local Neo4j
  5. Emit PMSUpdated event
"""
from __future__ import annotations
import json
from typing import Any, Dict, List, Optional

from neo4j import AsyncGraphDatabase
from shared.utils.kafka_consumer import EventConsumer
from shared.utils.kafka_producer import EventPublisher
from shared.utils.cloud_llm_client import CloudLLMClient, LLMMessage
from shared.utils.logging import get_logger

log = get_logger(__name__)

GRAPH_SYNTHESIS_PROMPT = """You are MASAREEN's Graph Synthesis Engine.
Given a verified impact asset and the user's current PMS dimension scores,
compute the dimension DELTAS that this new asset warrants.

PMS Dimensions (all values 0.0–1.0):
  reliability, execution_quality, leadership, documentation_quality,
  verification_confidence, learning_velocity, technical_skills,
  innovation, consistency, community_impact

Rules:
- Deltas must be small incremental adjustments (max ±0.05 per event)
- Only adjust dimensions directly evidenced by the activity
- Never set a dimension below 0.0 or above 1.0 after application

Respond ONLY in valid JSON:
{
  "dimension_deltas": {
    "reliability": 0.02,
    "execution_quality": 0.03,
    "community_impact": 0.01
  },
  "reasoning": "one sentence",
  "cypher_node_merge": "MERGE (a:ImpactAsset {id: $asset_id}) SET a.title=$title, a.value_usd=$value, a.sdg=$sdg"
}"""


class GraphSynthesisEngine(EventConsumer):
    """
    Consumes: masaren.reputation.impact_asset_created.v1
    Emits:    masaren.identity.pms_updated.v1
    Writes:   Neo4j (local), ImpactAsset nodes, GENERATED relationships, PMS scores
    """

    CONSUME_TOPICS = ["masaren.reputation.impact_asset_created.v1"]
    EMIT_TOPIC     = "masaren.identity.pms_updated.v1"
    GROUP_ID       = "graph-synthesis-engine"

    def __init__(
        self,
        llm_client: CloudLLMClient,
        publisher: EventPublisher,
        neo4j_uri: str,
        neo4j_user: str,
        neo4j_password: str,
    ) -> None:
        super().__init__(topics=self.CONSUME_TOPICS, group_id=self.GROUP_ID)
        self._llm       = llm_client
        self._publisher = publisher
        self._neo4j_driver = AsyncGraphDatabase.driver(neo4j_uri, auth=(neo4j_user, neo4j_password))

    async def handle_event(
        self,
        event_type: str,
        payload: Dict[str, Any],
        topic: str,
        partition: int,
        offset: int,
    ) -> None:
        if event_type != "ImpactAssetCreated":
            return

        asset_id   = payload.get("aggregate_id", "")
        user_id    = payload.get("user_id", "")
        asset_data = {
            "title":         payload.get("asset_title", ""),
            "value_usd":     payload.get("economic_value_usd", 0.0),
            "sdg_primary":   payload.get("sdg_primary", 0),
            "magnitude":     payload.get("impact_magnitude", "MEDIUM"),
            "impact_category": payload.get("impact_category", "SOCIAL"),
        }

        log.info("graph_synthesis_processing", asset_id=asset_id, user_id=user_id)

        # 1. Write asset node to Neo4j (local)
        await self._merge_asset_node(asset_id, user_id, asset_data)

        # 2. Fetch current PMS dimensions from Neo4j
        current_pms = await self._get_current_pms(user_id)

        # 3. Send to cloud LLM for PMS delta reasoning
        context = {
            "asset": asset_data,
            "current_pms_dimensions": current_pms,
            "user_id": user_id,
        }
        try:
            response = await self._llm.complete(
                messages=[
                    LLMMessage(role="system", content=GRAPH_SYNTHESIS_PROMPT),
                    LLMMessage(role="user", content=json.dumps(context)),
                ],
                temperature=0.1,
                json_mode=True,
            )
            result = json.loads(response.text)
        except Exception as exc:
            log.error("graph_synthesis_llm_failed", error=str(exc))
            return

        # 4. Apply PMS deltas to Neo4j
        deltas = result.get("dimension_deltas", {})
        new_dimensions = {}
        for dim, current_val in current_pms.items():
            delta = deltas.get(dim, 0.0)
            new_dimensions[dim] = round(max(0.0, min(1.0, current_val + delta)), 4)

        await self._update_pms_in_graph(user_id, new_dimensions)

        # 5. Compute composite score
        composite = round(sum(new_dimensions.values()) / len(new_dimensions), 4) if new_dimensions else 0.0

        # 6. Emit PMSUpdated event
        from shared.events import DomainEvent
        from dataclasses import dataclass

        @dataclass
        class PMSUpdated(DomainEvent):
            event_type:    str   = "PMSUpdated"
            aggregate_type: str  = "User"
            previous_score: float = 0.0
            new_score:     float  = 0.0
            dimensions:    dict   = None

            def __post_init__(self):
                if self.dimensions is None:
                    self.dimensions = {}

        previous_composite = round(sum(current_pms.values()) / len(current_pms), 4) if current_pms else 0.0
        event = PMSUpdated(
            aggregate_id=user_id,
            previous_score=previous_composite,
            new_score=composite,
            dimensions=new_dimensions,
        )
        await self._publisher.publish(self.EMIT_TOPIC, event, key=user_id)
        log.info("pms_updated", user_id=user_id, new_score=composite, deltas=deltas)

    async def _merge_asset_node(self, asset_id: str, user_id: str, asset_data: Dict) -> None:
        cypher = """
        MERGE (a:ImpactAsset {id: $asset_id})
        SET a.title       = $title,
            a.value_usd   = $value_usd,
            a.sdg_primary = $sdg_primary,
            a.magnitude   = $magnitude,
            a.category    = $category,
            a.created_at  = datetime()
        WITH a
        MATCH (p:Person {id: $user_id})
        MERGE (p)-[:GENERATED]->(a)
        """
        async with self._neo4j_driver.session() as session:
            await session.run(cypher, {
                "asset_id":   asset_id,
                "user_id":    user_id,
                "title":      asset_data.get("title", ""),
                "value_usd":  asset_data.get("value_usd", 0.0),
                "sdg_primary": asset_data.get("sdg_primary", 0),
                "magnitude":  asset_data.get("magnitude", "MEDIUM"),
                "category":   asset_data.get("impact_category", "SOCIAL"),
            })

    async def _get_current_pms(self, user_id: str) -> Dict[str, float]:
        cypher = "MATCH (p:Person {id: $user_id}) RETURN p.pms_dimensions AS dims"
        async with self._neo4j_driver.session() as session:
            result = await session.run(cypher, {"user_id": user_id})
            record = await result.single()
            if record and record["dims"]:
                try:
                    return json.loads(record["dims"])
                except Exception:
                    pass
        # Default zero dimensions
        return {k: 0.0 for k in [
            "reliability", "execution_quality", "leadership",
            "documentation_quality", "verification_confidence",
            "learning_velocity", "technical_skills", "innovation",
            "consistency", "community_impact",
        ]}

    async def _update_pms_in_graph(self, user_id: str, dimensions: Dict[str, float]) -> None:
        import json as _json
        cypher = """
        MERGE (p:Person {id: $user_id})
        SET p.pms_dimensions = $dims_json,
            p.pms_composite  = $composite,
            p.updated_at     = datetime()
        """
        composite = round(sum(dimensions.values()) / len(dimensions), 4)
        async with self._neo4j_driver.session() as session:
            await session.run(cypher, {
                "user_id":   user_id,
                "dims_json": _json.dumps(dimensions),
                "composite": composite,
            })
