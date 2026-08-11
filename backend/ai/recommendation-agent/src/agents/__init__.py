"""
Recommendation Agent — proactive opportunity and skill recommendations.
Consumes: masaren.identity.pms_updated.v1
Emits:    masaren.marketplace.opportunity_recommended.v1
"""
from __future__ import annotations
import json
from typing import Any, Dict
from shared.utils.kafka_consumer import EventConsumer
from shared.utils.kafka_producer import EventPublisher
from shared.utils.cloud_llm_client import CloudLLMClient, LLMMessage
from shared.utils.logging import get_logger

log = get_logger(__name__)

RECOMMENDATION_PROMPT = """You are MASAREEN's Opportunity Broker AI.
Given a user's updated PMS dimensions and skills, suggest the most relevant
opportunity types and skills to develop.
Respond ONLY in valid JSON:
{
  "recommended_opp_types": ["JOB", "SCHOLARSHIP"],
  "skill_gaps": ["grant-writing", "data-analysis"],
  "suggested_sdgs_to_focus": [4, 10],
  "action_items": ["Complete 2 more education tasks to boost SDG-4 credentials"],
  "confidence": 0.85
}"""


class RecommendationAgent(EventConsumer):
    CONSUME_TOPICS = ["masaren.identity.pms_updated.v1"]
    EMIT_TOPIC     = "masaren.marketplace.opportunity_recommended.v1"
    GROUP_ID       = "recommendation-agent"

    def __init__(self, llm_client: CloudLLMClient, publisher: EventPublisher):
        super().__init__(topics=self.CONSUME_TOPICS, group_id=self.GROUP_ID)
        self._llm = llm_client
        self._publisher = publisher

    async def handle_event(self, event_type: str, payload: Dict[str, Any],
                           topic: str, partition: int, offset: int) -> None:
        if event_type != "PMSUpdated":
            return
        user_id    = payload.get("aggregate_id", "")
        new_score  = payload.get("new_score", 0.0)
        dimensions = payload.get("dimensions", {})
        log.info("recommendation_agent_processing", user_id=user_id, pms=new_score)
        try:
            resp = await self._llm.complete(
                messages=[
                    LLMMessage(role="system", content=RECOMMENDATION_PROMPT),
                    LLMMessage(role="user", content=json.dumps({
                        "user_id": user_id,
                        "pms_score": new_score,
                        "dimensions": dimensions,
                    })),
                ],
                temperature=0.4, json_mode=True,
            )
            recs = json.loads(resp.text)
            log.info("recommendations_generated", user_id=user_id,
                     opp_types=recs.get("recommended_opp_types", []))
        except Exception as exc:
            log.error("recommendation_agent_failed", error=str(exc))
