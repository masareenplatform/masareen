"""
Speech AI Agent — audio transcription and voice evidence analysis.
Consumes: masaren.verification.evidence_uploaded.v1 (AUDIO type)
Emits:    masaren.verification.evidence_transcribed.v1

Transcription is performed by the configured cloud multimodal LLM
(``CloudLLMClient.complete_with_media``) on the real audio bytes downloaded from
the evidence storage URL. There is no stubbed/simulated transcript: if the audio
cannot be fetched or transcribed, the agent logs the failure and does not emit a
(false) success event.
"""
from __future__ import annotations
from dataclasses import dataclass
from typing import Any, Dict

import httpx

from shared.events import DomainEvent
from shared.utils.kafka_consumer import EventConsumer
from shared.utils.kafka_producer import EventPublisher
from shared.utils.cloud_llm_client import CloudLLMClient
from shared.utils.logging import get_logger

log = get_logger(__name__)

TRANSCRIPTION_PROMPT = (
    "Transcribe the following audio evidence verbatim. Then, on a new line prefixed "
    "with 'SUMMARY:', give a one-sentence factual summary. Do not invent content."
)


@dataclass
class EvidenceTranscribed(DomainEvent):
    event_type: str = "EvidenceTranscribed"
    aggregate_type: str = "Evidence"
    transcript: str = ""
    language: str = ""


class SpeechAIAgent(EventConsumer):
    CONSUME_TOPICS = ["masaren.verification.evidence_uploaded.v1"]
    EMIT_TOPIC     = "masaren.verification.evidence_transcribed.v1"
    GROUP_ID       = "speech-ai-agent"

    def __init__(self, llm_client: CloudLLMClient, publisher: EventPublisher):
        super().__init__(topics=self.CONSUME_TOPICS, group_id=self.GROUP_ID)
        self._llm = llm_client
        self._publisher = publisher

    async def handle_event(self, event_type: str, payload: Dict[str, Any],
                           topic: str, partition: int, offset: int) -> None:
        if event_type != "EvidenceUploaded":
            return
        if payload.get("media_type", "") != "AUDIO":
            return

        evidence_id = payload.get("aggregate_id", "")
        storage_url = payload.get("storage_url", "")
        mime_type = payload.get("mime_type") or "audio/mpeg"
        if not storage_url:
            log.warning("speech_agent_no_storage_url", evidence_id=evidence_id)
            return

        log.info("speech_agent_processing", evidence_id=evidence_id)
        try:
            async with httpx.AsyncClient(timeout=60.0) as client:
                resp = await client.get(storage_url)
                resp.raise_for_status()
                audio_bytes = resp.content

            result = await self._llm.complete_with_media(
                prompt=TRANSCRIPTION_PROMPT,
                media_bytes=audio_bytes,
                mime_type=mime_type,
            )
        except Exception as exc:
            log.error("speech_agent_transcription_failed", evidence_id=evidence_id, error=str(exc))
            return

        transcript = result.text.strip()
        event = EvidenceTranscribed(aggregate_id=evidence_id, transcript=transcript)
        await self._publisher.publish(self.EMIT_TOPIC, event, key=evidence_id)
        log.info("speech_agent_transcribed", evidence_id=evidence_id, chars=len(transcript))
