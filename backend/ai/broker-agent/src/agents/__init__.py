"""
Broker Agent — funding opportunity discovery and matching.
Consumes: masaren.reputation.impact_asset_created.v1
Emits:    masaren.marketplace.funding_recommended.v1
"""
from __future__ import annotations
import json
from typing import Any, Dict
from shared.utils.kafka_consumer import EventConsumer
from shared.utils.kafka_producer import EventPublisher
from shared.utils.cloud_llm_client import CloudLLMClient, LLMMessage
from shared.utils.logging import get_logger

log = get_logger(__name__)

BROKER_PROMPT = """You are MASAREEN's Funding Broker AI.
Given a verified impact asset, identify matching funding opportunities,
grants, and scholarships the creator could apply for.
Respond ONLY in valid JSON:
{
  "funding_matches": [
    {
      "source": "UN Women Fund",
      "type": "GRANT",
      "estimated_amount_usd": 25000,
      "match_reason": "SDG-5 alignment and verified field evidence",
      "application_url": "https://example.com/apply",
      "deadline_hint": "Q2 2026"
    }
  ],
  "confidence": 0.72
}"""


class BrokerAgent(EventConsumer):
    CONSUME_TOPICS = ["masaren.reputation.impact_asset_created.v1"]
    EMIT_TOPIC     = "masaren.marketplace.funding_recommended.v1"
    GROUP_ID       = "broker-agent"

    def __init__(self, llm_client: CloudLLMClient, publisher: EventPublisher):
        super().__init__(topics=self.CONSUME_TOPICS, group_id=self.GROUP_ID)
        self._llm = llm_client
        self._publisher = publisher

    async def handle_event(self, event_type: str, payload: Dict[str, Any],
                           topic: str, partition: int, offset: int) -> None:
        if event_type != "ImpactAssetCreated":
            return
        asset_id = payload.get("aggregate_id", "")
        sdg_tags = payload.get("sdg_tags", [])
        log.info("broker_agent_matching", asset_id=asset_id, sdgs=sdg_tags)
        try:
            resp = await self._llm.complete(
                messages=[
                    LLMMessage(role="system", content=BROKER_PROMPT),
                    LLMMessage(role="user", content=json.dumps({
                        "asset_id": asset_id, "sdg_tags": sdg_tags,
                        "impact_category": payload.get("impact_category",""),
                        "impact_magnitude": payload.get("impact_magnitude",""),
                        "economic_value_usd": payload.get("economic_value_usd", 0),
                    })),
                ],
                temperature=0.3, json_mode=True,
            )
            matches = json.loads(resp.text)
            log.info("broker_matches_found", asset_id=asset_id,
                     count=len(matches.get("funding_matches", [])))
        except Exception as exc:
            log.error("broker_agent_failed", error=str(exc))
