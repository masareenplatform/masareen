from __future__ import annotations

from ..agents.verification_agents import VerificationAgents


def _Task():  # lazy import of the optional crewai dependency
    from crewai import Task
    return Task


class VerificationTasks:
    def __init__(self, agents: VerificationAgents):
        self.agents = agents

    def analyze_evidence_task(self, evidence_id: str) -> Task:
        return _Task(
            description=(
                f"Fetch the details for evidence ID '{evidence_id}' using the MASAREEN BFF. "
                "Analyze any reported anomalies (GPS, checksum, metadata) for signs of fraud. "
                "Determine the fraud type, risk score, and recommended action (PASS | FLAG | SUSPEND_USER | ESCALATE)."
            ),
            expected_output="A detailed fraud analysis report including verdict, confidence, and reasoning.",
            agent=self.agents.fraud_auditor_agent()
        )

    def verify_visual_consistency_task(self, evidence_id: str) -> Task:
        return _Task(
            description=(
                f"Fetch the visual analysis and scene description for evidence ID '{evidence_id}' from the MASAREEN BFF. "
                "Evaluate the scene description for contextual consistency and check for red flags "
                "(e.g., digital manipulation, low resolution, or ambiguous context). "
                "Determine if the visual evidence is authentic."
            ),
            expected_output="A visual authenticity report including scene summary and red flag assessment.",
            agent=self.agents.visual_integrity_agent()
        )

    def poai_deliberation_task(self, evidence_id: str) -> Task:
        return _Task(
            description=(
                f"Perform a POAI deliberation on the verification of evidence '{evidence_id}'. "
                "1. Analyze the initial reports from the Fraud Auditor and Visual Integrity agents. "
                "2. Identify any discrepancies, over-confidences, or gaps in reasoning. "
                "3. Challenge the initial findings and deliberate on the most probable objective truth. "
                "4. Provide a refined set of findings that will be used for the final verdict."
            ),
            expected_output="A deliberation log detailing the conflict resolution and the refined evidence assessment.",
            agent=self.agents.deliberation_agent()
        )

    def final_verification_report_task(self) -> Task:
        return _Task(
            description=(
                "Review the findings from both the Fraud Auditor and the Visual Integrity agents, "
                "as well as the deliberations from the POAI Deliberation Agent. "
                "Synthesize these into a single, unified 'Final Verification Report'. "
                "This report should provide a final recommendation (APPROVED | NEEDS_REVIEW | REJECTED) "
                "and a summary of all supporting evidence and reasoning, highlighting how the "
                "deliberation process refined the initial verdict."
            ),
            expected_output="A consolidated, professional final verification report in markdown format.",
            agent=self.agents.reporter_agent()
        )
