"""
Planner Agent — AI-powered program and task planning.
Consumes: masaren.execution.program_created.v1
Emits:    masaren.execution.task_created.v1 (suggested tasks)
"""
from __future__ import annotations
import json
from typing import Any, Dict
from shared.utils.kafka_consumer import EventConsumer
from shared.utils.kafka_producer import EventPublisher
from shared.utils.cloud_llm_client import CloudLLMClient, LLMMessage
from shared.utils.logging import get_logger

log = get_logger(__name__)

PLANNER_PROMPT = """You are MASAREEN's Program Planner AI.
Given a program description and SDG goals, generate a structured task plan.
Respond ONLY in valid JSON:
{
  "tasks": [
    {
      "title": "task title",
      "description": "what to do",
      "priority": "HIGH|MEDIUM|LOW",
      "estimated_hours": 2.0,
      "evidence_required": true,
      "requires_gps": true,
      "sdg_contribution": [3, 6],
      "suggested_order": 1
    }
  ],
  "program_notes": "brief planning notes",
  "estimated_total_hours": 12.0,
  "recommended_team_size": 5
}"""


class PlannerAgent(EventConsumer):
    CONSUME_TOPICS = ["masaren.execution.program_created.v1"]
    EMIT_TOPIC     = "masaren.execution.task_suggested.v1"
    GROUP_ID       = "planner-agent"

    def __init__(self, llm_client: CloudLLMClient, publisher: EventPublisher):
        super().__init__(topics=self.CONSUME_TOPICS, group_id=self.GROUP_ID)
        self._llm = llm_client
        self._publisher = publisher

    async def handle_event(self, event_type: str, payload: Dict[str, Any],
                           topic: str, partition: int, offset: int) -> None:
        if event_type != "ProgramCreated":
            return
        program_id  = payload.get("aggregate_id", "")
        title       = payload.get("title", "")
        sdg_goals   = payload.get("sdg_goals", [])
        log.info("planner_agent_processing", program_id=program_id)
        try:
            resp = await self._llm.complete(
                messages=[
                    LLMMessage(role="system", content=PLANNER_PROMPT),
                    LLMMessage(role="user", content=json.dumps({
                        "program_title": title,
                        "sdg_goals": sdg_goals,
                        "program_id": program_id,
                    })),
                ],
                temperature=0.3, json_mode=True,
            )
            plan = json.loads(resp.text)
            log.info("planner_agent_plan_generated",
                program_id=program_id, task_count=len(plan.get("tasks", [])))
        except Exception as exc:
            log.error("planner_agent_failed", error=str(exc))
