"""
Compliance Agent — policy enforcement and regulatory checks.
Consumes: masaren.reporting.report_generated.v1
Emits:    masaren.compliance.issue_flagged.v1
"""
from __future__ import annotations
from typing import Any, Dict
from shared.utils.kafka_consumer import EventConsumer
from shared.utils.kafka_producer import EventPublisher
from shared.utils.cloud_llm_client import CloudLLMClient, LLMMessage
from shared.utils.logging import get_logger

log = get_logger(__name__)


class ComplianceAgent(EventConsumer):
    CONSUME_TOPICS = ["masaren.reporting.report_generated.v1"]
    EMIT_TOPIC     = "masaren.compliance.issue_flagged.v1"
    GROUP_ID       = "compliance-agent"

    def __init__(self, llm_client: CloudLLMClient, publisher: EventPublisher):
        super().__init__(topics=self.CONSUME_TOPICS, group_id=self.GROUP_ID)
        self._llm = llm_client
        self._publisher = publisher

    async def handle_event(self, event_type: str, payload: Dict[str, Any],
                           topic: str, partition: int, offset: int) -> None:
        if event_type != "ReportGenerated":
            return
        report_id = payload.get("aggregate_id", "")
        log.info("compliance_agent_reviewing", report_id=report_id)
        # Future: check SDG metric completeness, donor reporting standards, etc.
