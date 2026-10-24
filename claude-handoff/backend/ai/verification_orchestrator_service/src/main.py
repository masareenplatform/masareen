from fastapi import FastAPI, BackgroundTasks, HTTPException
from pydantic import BaseModel
from typing import Optional, List, Dict, Any
from shared.dtos import ApiResponse, VerificationRequest
import httpx

from .agents.verification_agents import VerificationAgents
from .tasks.verification_tasks import VerificationTasks
from .utils.blackboard import blackboard

# `crewai` is a heavy, optional dependency. Import it lazily so the service
# module (and its API/tests) can be imported even when crewai is not installed;
# the crew is only required to run an end-to-end verification.
try:
    from crewai import Crew, Process
except Exception:  # pragma: no cover - optional dep
    Crew = None
    Process = None

try:
    from config import settings
except Exception:  # pragma: no cover
    from ..config import settings  # type: ignore

app = FastAPI(title="MASAREN Verification Orchestrator")


# Agents/Tasks are built lazily: constructing them requires the optional
# crewai + langchain LLM dependencies, which are only needed to actually run
# a verification crew (not for the health/report/admin endpoints).
def _get_factories():
    agents = VerificationAgents()
    tasks = VerificationTasks(agents)
    return agents, tasks


_agents_factory: "VerificationAgents | None" = None
_tasks_factory: "VerificationTasks | None" = None


def _factories():
    global _agents_factory, _tasks_factory
    if _agents_factory is None or _tasks_factory is None:
        _agents_factory, _tasks_factory = _get_factories()
    return _agents_factory, _tasks_factory


class ApprovalRequest(BaseModel):
    review_id: str            # audit-service review queue item id
    verdict: str              # APPROVED | REJECTED | REQUEST_INFO
    admin_id: str
    comments: str = ""


def route_to_human_review(evidence_id: str, confidence: float) -> None:
    """Route a low-confidence result to the real audit-service review queue.

    Runs synchronously (called from the crew worker thread), no event-loop
    juggling. Failures are recorded to the blackboard, not swallowed silently.
    """
    try:
        resp = httpx.post(
            f"{settings.audit_service_url}/review/route",
            json={"entity_id": evidence_id, "entity_type": "EVIDENCE",
                  "confidence_score": confidence},
            timeout=10.0,
        )
        resp.raise_for_status()
    except Exception as e:
        blackboard.log("ERROR", "REVIEW_ROUTING_FAILED",
                       f"Could not route {evidence_id} to review: {str(e)}")

def run_crew_logic(evidence_id: str) -> str:
    """The core CrewAI logic to verify evidence."""
    blackboard.log("SYSTEM", "START_CREW", f"Initializing POAI verification crew for: {evidence_id}")

    if Crew is None or Process is None:
        msg = "crewai is not installed; cannot run verification crew"
        blackboard.log("ERROR", "CREW_UNAVAILABLE", msg)
        return f"Failure: {msg}"

    agents_factory, tasks_factory = _factories()

    fraud_task = tasks_factory.analyze_evidence_task(evidence_id)
    visual_task = tasks_factory.verify_visual_consistency_task(evidence_id)
    deliberation_task = tasks_factory.poai_deliberation_task(evidence_id)
    report_task = tasks_factory.final_verification_report_task()

    crew = Crew(
        agents=[
            agents_factory.fraud_auditor_agent(),
            agents_factory.visual_integrity_agent(),
            agents_factory.deliberation_agent(),
            agents_factory.reporter_agent()
        ],
        tasks=[fraud_task, visual_task, deliberation_task, report_task],
        process=Process.sequential,
        verbose=True
    )

    try:
        result = crew.kickoff()
        result_str = str(result)

        # Extract confidence score from report (agents output "Confidence: 0.XX")
        import re
        conf_match = re.search(r"Confidence:\s*([0-9.]+)", result_str)
        confidence = float(conf_match.group(1)) if conf_match else 0.5

        if confidence < settings.hitl_confidence_threshold:
            blackboard.log("HITL", "PENDING", f"Evidence {evidence_id} confidence {confidence} too low. Routing to human review.")
            route_to_human_review(evidence_id, confidence)
        else:
            blackboard.log("CREW", "COMPLETE", f"Verification completed for {evidence_id} with confidence {confidence}")

        return result_str
    except Exception as e:
        blackboard.log("ERROR", "CREW_FAILURE", str(e))
        return f"Failure: {str(e)}"

@app.post("/verify", response_model=ApiResponse[dict])
async def trigger_verification(req: VerificationRequest, background_tasks: BackgroundTasks):
    """Trigger a POAI verification process asynchronously."""
    if not req.evidence_id:
        raise HTTPException(status_code=400, detail="evidence_id is required for this endpoint")
    background_tasks.add_task(run_crew_logic, req.evidence_id)
    return ApiResponse.ok({"status": "ACCEPTED", "message": f"Verification started for {req.evidence_id}"})

@app.get("/report/{evidence_id}", response_model=ApiResponse[str])
async def get_report(evidence_id: str):
    logs = blackboard.get_latest()
    return ApiResponse.ok(logs)

@app.get("/admin/pending", response_model=ApiResponse[List[Dict[str, Any]]])
async def get_pending_approvals():
    """Real pending human-review items from the audit-service review queue."""
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(f"{settings.audit_service_url}/review/pending")
            resp.raise_for_status()
            body = resp.json()
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"audit_service_unavailable: {e}")
    return ApiResponse.ok(body.get("data", []))


@app.post("/admin/approve", response_model=ApiResponse[dict])
async def approve_verification(req: ApprovalRequest):
    """Resolve a review item in the audit-service (the real queue owner)."""
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.patch(
                f"{settings.audit_service_url}/review/{req.review_id}/resolve",
                json={"verdict": req.verdict, "comments": req.comments, "admin_id": req.admin_id},
            )
            resp.raise_for_status()
            body = resp.json()
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"audit_service_unavailable: {e}")
    blackboard.log("HITL", "RESOLVED", f"Review {req.review_id} resolved as {req.verdict} by {req.admin_id}.")
    return ApiResponse.ok(body.get("data", {"review_id": req.review_id, "verdict": req.verdict}))

@app.get("/health")
async def health():
    return {"status": "healthy"}
