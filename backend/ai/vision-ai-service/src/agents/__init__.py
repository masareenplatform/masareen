"""
Vision AI Agent, consumes evidence upload events, calls cloud VLM,
emits EvidenceVerified or EvidenceFlaggedForReview.

Hardware note: 0GB VRAM on deployment server.
All inference routes to cloud provider (OpenAI GPT-4o / Google Gemini Pro Vision).
"""
from __future__ import annotations
import json
from typing import Any, Dict

from shared.utils.kafka_consumer import EventConsumer
from shared.utils.kafka_producer import EventPublisher
from shared.utils.cloud_llm_client import CloudLLMClient, LLMMessage
from shared.utils.logging import get_logger

log = get_logger(__name__)

VISION_SYSTEM_PROMPT = """You are MASAREEN's Vision AI Agent, a specialized evidence integrity auditor.
You analyse field evidence photos and videos submitted by participants in social impact programs.

For each image, evaluate and respond ONLY in valid JSON with this exact schema:
{
  "authentic": true/false,
  "confidence": 0.0-1.0,
  "scene_description": "brief description of what is visible",
  "red_flags": ["list of any anomalies or concerns"],
  "verdict": "APPROVED | NEEDS_REVIEW | REJECTED",
  "reasoning": "one sentence explanation"
}

Flag as REJECTED if: obvious digital manipulation, stock photo signatures, metadata inconsistencies,
scene does not match declared activity, or duplicate content detected.
Flag as NEEDS_REVIEW if: low resolution, partially visible scene, or ambiguous context."""


class VisionAIAgent(EventConsumer):
    """
    Consumes: masaren.verification.evidence_uploaded.v1
    Emits:    masaren.verification.evidence_verified.v1
    """

    CONSUME_TOPICS = ["masaren.verification.evidence_uploaded.v1"]
    EMIT_TOPIC     = "masaren.verification.evidence_verified.v1"
    GROUP_ID       = "vision-ai-agent"

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
        if event_type != "EvidenceUploaded":
            return

        evidence_id  = payload.get("aggregate_id", "")
        storage_url  = payload.get("storage_url", "")
        media_type   = payload.get("media_type", "PHOTO")

        log.info("vision_agent_processing", evidence_id=evidence_id, media_type=media_type)

        # Fetch image bytes from storage URL
        try:
            import httpx
            async with httpx.AsyncClient(timeout=30.0) as client:
                img_resp = await client.get(storage_url)
                img_resp.raise_for_status()
                image_bytes = img_resp.content
                content_type = img_resp.headers.get("content-type", "image/jpeg")
        except Exception as exc:
            log.error("vision_agent_fetch_failed", evidence_id=evidence_id, error=str(exc))
            return

        # Call cloud VLM
        try:
            llm_response = await self._llm.complete_with_image(
                prompt=VISION_SYSTEM_PROMPT,
                image_bytes=image_bytes,
                image_mime=content_type,
            )
            analysis = json.loads(llm_response.text)
        except Exception as exc:
            log.error("vision_agent_llm_failed", evidence_id=evidence_id, error=str(exc))
            # Fail safe: route to human review
            analysis = {
                "authentic": False,
                "confidence": 0.0,
                "verdict": "NEEDS_REVIEW",
                "reasoning": f"AI analysis failed: {exc}",
                "red_flags": ["AI_ANALYSIS_FAILED"],
            }

        # Emit result event
        from shared.events import DomainEvent
        from dataclasses import dataclass

        @dataclass
        class EvidenceVerified(DomainEvent):
            event_type:       str   = "EvidenceVerified"
            aggregate_type:   str   = "Evidence"
            verifier_type:    str   = "AI"
            confidence_score: float = 0.0
            verdict:          str   = "NEEDS_REVIEW"
            red_flags:        list  = None
            scene_description: str  = ""

            def __post_init__(self):
                if self.red_flags is None:
                    self.red_flags = []

        event = EvidenceVerified(
            aggregate_id=evidence_id,
            verifier_type="AI",
            confidence_score=analysis.get("confidence", 0.0),
            verdict=analysis.get("verdict", "NEEDS_REVIEW"),
            red_flags=analysis.get("red_flags", []),
            scene_description=analysis.get("scene_description", ""),
        )

        await self._publisher.publish(self.EMIT_TOPIC, event, key=evidence_id)
        log.info(
            "vision_agent_verdict",
            evidence_id=evidence_id,
            verdict=analysis.get("verdict"),
            confidence=analysis.get("confidence"),
        )
