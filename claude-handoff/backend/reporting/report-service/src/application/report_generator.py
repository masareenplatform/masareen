"""AI-powered narrative synthesis for MASAREN impact reports.

This module NEVER fabricates metrics. It receives real metrics (computed by
``ReportRepository`` from the platform's relational tables) and asks the cloud
LLM to write a professional narrative around those exact numbers. If no LLM is
configured, a deterministic text summary of the same real metrics is returned.
"""
from typing import Any, Dict, Optional
from shared.utils.logging import get_logger
from shared.utils.cloud_llm_client import CloudLLMClient, LLMMessage

log = get_logger(__name__)


class ReportGenerator:
    """Turns REAL metrics into an executive narrative (optional LLM enrichment)."""

    def __init__(self, llm_client: Optional[CloudLLMClient] = None):
        self.llm = llm_client

    async def synthesize_narrative(self, entity_id: str, entity_type: str,
                                   tier: str, metrics: Dict[str, Any]) -> str:
        """Return an executive summary grounded in the supplied real metrics."""
        if self.llm is None:
            return self._deterministic_summary(entity_type, entity_id, metrics)

        system = ("You are an expert impact auditor. Write a professional, factual "
                  "executive summary. Use ONLY the metrics provided; never invent numbers.")
        user = (f"Entity type: {entity_type}\nEntity id: {entity_id}\n"
                f"Verified metrics (source of truth): {metrics}")
        if tier == "COMPREHENSIVE":
            user += ("\nInclude critical analysis of verification confidence and "
                     "strategic recommendations, strictly derived from these metrics.")
        try:
            resp = await self.llm.complete(
                messages=[LLMMessage(role="system", content=system),
                          LLMMessage(role="user", content=user)],
            )
            return resp.text
        except Exception as exc:  # LLM unavailable → fall back to real-metric summary
            log.warning("report_llm_unavailable_fallback", error=str(exc))
            return self._deterministic_summary(entity_type, entity_id, metrics)

    @staticmethod
    def _deterministic_summary(entity_type: str, entity_id: str, metrics: Dict[str, Any]) -> str:
        parts = [f"Impact summary for {entity_type} {entity_id}."]
        for k, v in metrics.items():
            parts.append(f"{k.replace('_', ' ').title()}: {v}.")
        return " ".join(parts)
