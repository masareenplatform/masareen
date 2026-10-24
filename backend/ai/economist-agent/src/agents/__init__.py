"""
Impact Economist Agent, translates verified field activities into
standardised social-economic value metrics.

Frameworks: ILO volunteer valuation, UN SDG indicator mapping,
SROI (Social Return on Investment), IRIS+ metrics.

Consumes: masaren.verification.evidence_verified.v1 (APPROVED only)
Emits:    masaren.reputation.impact_asset_created.v1
"""
from __future__ import annotations
import json
from typing import Any, Dict, List

from shared.utils.kafka_consumer import EventConsumer
from shared.utils.kafka_producer import EventPublisher
from shared.utils.cloud_llm_client import CloudLLMClient, LLMMessage
from shared.utils.logging import get_logger

log = get_logger(__name__)

ECONOMIST_SYSTEM_PROMPT = """You are MASAREEN's Impact Economist, an expert in social value measurement.
You translate verified field activities into standardised economic and social impact metrics.

Use these international frameworks:
- ILO minimum wage × hours for volunteer labour valuation
- UN SDG indicator alignment (Goals 1–17)
- IRIS+ output/outcome metrics
- SROI proxy values where applicable

Given a verified activity, respond ONLY in valid JSON:
{
  "economic_value_usd": 0.00,
  "valuation_method": "ILO_WAGE | SROI_PROXY | MARKET_RATE",
  "sdg_alignment": [1, 3, 10],
  "sdg_primary": 3,
  "iris_metrics": ["PI9999", "OI1234"],
  "impact_category": "HEALTH | EDUCATION | ENVIRONMENT | ECONOMIC | GOVERNANCE | SOCIAL",
  "impact_magnitude": "LOW | MEDIUM | HIGH | TRANSFORMATIVE",
  "asset_title": "short human-readable title for this impact asset",
  "confidence": 0.0-1.0
}"""


class ImpactEconomistAgent(EventConsumer):
    """
    Consumes: masaren.verification.evidence_verified.v1
    Emits:    masaren.reputation.impact_asset_created.v1
    """

    CONSUME_TOPICS = ["masaren.verification.evidence_verified.v1"]
    EMIT_TOPIC     = "masaren.reputation.impact_asset_created.v1"
    GROUP_ID       = "impact-economist-agent"

    def __init__(self, llm_client: CloudLLMClient, publisher: EventPublisher) -> None:
        super().__init__(topics=self.CONSUME_TOPICS, group_id=self.GROUP_ID)
        self._llm       = llm_client
        self._publisher = publisher

    async def handle_event(
        self,
        event_type: str,
        payload: Dict[str, Any],
        topic: str,
        partition: int,
        offset: int,
    ) -> None:
        if event_type != "EvidenceVerified":
            return

        verdict = payload.get("verdict", "")
        if verdict != "APPROVED":
            # Only compute value for approved evidence
            log.debug("economist_skipping", verdict=verdict, evidence_id=payload.get("aggregate_id"))
            return

        evidence_id       = payload.get("aggregate_id", "")
        scene_description = payload.get("scene_description", "")
        task_context      = payload.get("metadata", {})

        log.info("economist_valuing", evidence_id=evidence_id)

        activity_context = {
            "scene_description": scene_description,
            "task_context": task_context,
            "confidence_from_vision": payload.get("confidence_score", 0.0),
        }

        try:
            response = await self._llm.complete(
                messages=[
                    LLMMessage(role="system", content=ECONOMIST_SYSTEM_PROMPT),
                    LLMMessage(role="user", content=json.dumps(activity_context)),
                ],
                temperature=0.1,
                json_mode=True,
            )
            valuation = json.loads(response.text)
        except Exception as exc:
            log.error("economist_llm_failed", error=str(exc), evidence_id=evidence_id)
            return

        # Emit ImpactAssetCreated event
        from shared.events import DomainEvent
        from dataclasses import dataclass, field

        @dataclass
        class ImpactAssetCreated(DomainEvent):
            event_type:       str   = "ImpactAssetCreated"
            aggregate_type:   str   = "ImpactAsset"
            evidence_id:      str   = ""
            user_id:          str   = ""
            asset_title:      str   = ""
            economic_value_usd: float = 0.0
            valuation_method: str   = ""
            sdg_tags:         list  = field(default_factory=list)
            sdg_primary:      int   = 0
            impact_category:  str   = ""
            impact_magnitude: str   = "MEDIUM"
            confidence:       float = 0.0

        from uuid import uuid4
        event = ImpactAssetCreated(
            aggregate_id=str(uuid4()),
            evidence_id=evidence_id,
            user_id=task_context.get("user_id", ""),
            asset_title=valuation.get("asset_title", "Verified Impact Activity"),
            economic_value_usd=valuation.get("economic_value_usd", 0.0),
            valuation_method=valuation.get("valuation_method", "ILO_WAGE"),
            sdg_tags=valuation.get("sdg_alignment", []),
            sdg_primary=valuation.get("sdg_primary", 0),
            impact_category=valuation.get("impact_category", "SOCIAL"),
            impact_magnitude=valuation.get("impact_magnitude", "MEDIUM"),
            confidence=valuation.get("confidence", 0.0),
        )

        await self._publisher.publish(self.EMIT_TOPIC, event)
        log.info(
            "impact_asset_created",
            evidence_id=evidence_id,
            value_usd=valuation.get("economic_value_usd"),
            sdg_primary=valuation.get("sdg_primary"),
            magnitude=valuation.get("impact_magnitude"),
        )
