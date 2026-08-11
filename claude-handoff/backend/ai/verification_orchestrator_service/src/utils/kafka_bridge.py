from shared.utils.kafka_consumer import EventConsumer
from shared.utils.kafka_producer import EventPublisher
from .main import run_crew_logic
from typing import Any, Dict

class VerificationKafkaBridge(EventConsumer):
    """
    Kafka Consumer that triggers the POAI Crew when a verification request is received.
    """
    CONSUME_TOPICS = ["masaren.verification.verification_requested.v1"]
    EMIT_TOPIC     = "masaren.verification.crewai_report.v1"
    GROUP_ID       = "verification-orchestrator-bridge"

    def __init__(self, publisher: EventPublisher):
        super().__init__(topics=self.CONSUME_TOPICS, group_id=self.GROUP_ID)
        self._publisher = publisher

    async def handle_event(
        self,
        event_type: str,
        payload: Dict[str, Any],
        topic: str,
        partition: int,
        offset: int,
    ) -> None:
        evidence_id = payload.get("aggregate_id")
        if not evidence_id:
            return

        # Run the crew and emit the result
        try:
            result = run_crew_logic(evidence_id)
            
            # Emit the resulting report back to the system
            from dataclasses import dataclass
            from shared.events import DomainEvent
            
            @dataclass
            class CrewAIReport(DomainEvent):
                event_type: str = "CrewAIReportGenerated"
                aggregate_type: str = "Evidence"
                report_content: str = ""
                status: str = "SUCCESS"

            event = CrewAIReport(
                aggregate_id=evidence_id,
                report_content=result,
                status="SUCCESS"
            )
            await self._publisher.publish(self.EMIT_TOPIC, event, key=evidence_id)
        except Exception as e:
            logger.error(f"Bridge Error: {e}")
