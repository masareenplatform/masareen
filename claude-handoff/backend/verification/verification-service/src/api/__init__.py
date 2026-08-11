"""Verification Service API endpoints."""
from fastapi import APIRouter, status, Depends, HTTPException
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any, AsyncGenerator
from shared.dtos import ApiResponse
from ..application.commands import (
    StartVerificationPipelineCommand,
    RecordAIVerificationResultCommand,
    StartFraudCheckCommand,
    StartHumanReviewCommand,
    RecordHumanVerdictCommand,
    SubmitVerificationCommand,
)
from ..application.queries import (
    GetVerificationPipelineByIdQuery,
    GetPipelineByEvidenceIdQuery,
    ListPendingVerificationPipelinesQuery,
    GetReviewQueueQuery,
)
from ..application.command_bus import CommandBus, QueryBus
from ..dependencies import get_command_bus, get_query_bus

router = APIRouter(prefix="/verification", tags=["Verification"])


class CreatePipelineRequest(BaseModel):
    evidence_id: str = Field(..., description="Evidence identifier")
    task_id: str = Field(..., description="Task identifier")
    submitted_by: str = Field(..., description="User who submitted the evidence")

    class Config:
        schema_extra = {
            "example": {
                "evidence_id": "uuid-123",
                "task_id": "task-456",
                "submitted_by": "user-789"
            }
        }


class HumanVerdictRequest(BaseModel):
    verdict: str = Field(..., description="Human review verdict (APPROVED, REJECTED, NEEDS_REVIEW)")
    reviewer_id: str = Field(..., description="Reviewer identifier")
    confidence: float = Field(0.95, ge=0.0, le=1.0, description="Reviewer-assigned confidence")
    notes: Optional[str] = Field(None, description="Review notes")

    class Config:
        schema_extra = {
            "example": {
                "verdict": "APPROVED",
                "reviewer_id": "reviewer-123",
                "notes": "Evidence verified successfully"
            }
        }


class AIResultRequest(BaseModel):
    evidence_id: str = Field(..., description="Evidence identifier")
    verdict: str = Field(..., description="AI verification verdict (APPROVED, REJECTED, NEEDS_REVIEW)")
    confidence: float = Field(..., ge=0.0, le=1.0, description="AI confidence score")
    notes: Optional[str] = Field(None, description="AI analysis notes")

    class Config:
        schema_extra = {
            "example": {
                "evidence_id": "uuid-123",
                "verdict": "APPROVED",
                "confidence": 0.95,
                "notes": "High confidence approval"
            }
        }


@router.post("/pipelines", status_code=status.HTTP_201_CREATED, response_model=ApiResponse[dict])
async def create_pipeline(
    body: CreatePipelineRequest,
    command_bus: CommandBus = Depends(get_command_bus)
):
    """Create a new verification pipeline for evidence."""
    try:
        cmd = StartVerificationPipelineCommand(
            evidence_id=body.evidence_id,
            task_id=body.task_id,
            submitted_by=body.submitted_by
        )
        result = await command_bus.send(cmd)
        return ApiResponse.ok({
            "pipeline_id": result["pipeline_id"],
            "status": result["status"],
            "evidence_id": body.evidence_id,
            "task_id": body.task_id,
            "submitted_by": body.submitted_by
        })
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/pipelines/{pipeline_id}/ai-review", response_model=ApiResponse[dict])
async def record_ai_verification_result(
    pipeline_id: str,
    body: AIResultRequest,
    command_bus: CommandBus = Depends(get_command_bus)
):
    """Record AI verification results for a pipeline."""
    try:
        cmd = RecordAIVerificationResultCommand(
            pipeline_id=pipeline_id,
            evidence_id=body.evidence_id,
            verdict=body.verdict,
            confidence=body.confidence,
            notes=body.notes
        )
        result = await command_bus.send(cmd)
        return ApiResponse.ok({
            "pipeline_id": pipeline_id,
            "evidence_id": body.evidence_id,
            "ai_verdict": body.verdict,
            "confidence": body.confidence,
            "status": "AI_REVIEW_COMPLETED"
        })
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/pipelines/{pipeline_id}/human-review", response_model=ApiResponse[dict])
async def start_human_review(
    pipeline_id: str,
    body: HumanVerdictRequest,
    command_bus: CommandBus = Depends(get_command_bus)
):
    """Start human review for a pipeline."""
    try:
        cmd = StartHumanReviewCommand(
            pipeline_id=pipeline_id,
            evidence_id="",
            reviewer_id=body.reviewer_id
        )
        result = await command_bus.send(cmd)
        return ApiResponse.ok({
            "pipeline_id": pipeline_id,
            "reviewer_id": body.reviewer_id,
            "status": "HUMAN_REVIEW_STARTED"
        })
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/pipelines/{pipeline_id}/human-verdict", response_model=ApiResponse[dict])
async def record_human_verdict(
    pipeline_id: str,
    body: HumanVerdictRequest,
    command_bus: CommandBus = Depends(get_command_bus)
):
    """Record human verification verdict."""
    try:
        cmd = RecordHumanVerdictCommand(
            pipeline_id=pipeline_id,
            evidence_id="",
            verdict=body.verdict,
            reviewer_id=body.reviewer_id,
            confidence=body.confidence,
            notes=body.notes
        )
        result = await command_bus.send(cmd)
        return ApiResponse.ok({
            "pipeline_id": pipeline_id,
            "human_verdict": body.verdict,
            "reviewer_id": body.reviewer_id,
            "status": "HUMAN_REVIEW_COMPLETED",
            "final_result": result.get("final_result")
        })
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/pipelines/{pipeline_id}", response_model=ApiResponse[dict])
async def get_pipeline(
    pipeline_id: str,
    query_bus: QueryBus = Depends(get_query_bus)
):
    """Get verification pipeline details."""
    try:
        query = GetVerificationPipelineByIdQuery(pipeline_id=pipeline_id)
        pipeline = await query_bus.ask(query)
        if not pipeline:
            raise HTTPException(status_code=404, detail="Pipeline not found")

        return ApiResponse.ok({
            "pipeline_id": pipeline.pipeline_id,
            "evidence_id": pipeline.evidence_id,
            "task_id": pipeline.task_id,
            "submitted_by": pipeline.submitted_by,
            "status": pipeline.status.value,
            "fraud_risk_score": pipeline.fraud_risk_score,
            "fraud_risk_details": pipeline.fraud_risk_details,
            "final_verdict": pipeline.final_verdict,
            "assigned_reviewer": pipeline.assigned_reviewer,
            "ai_confidence_score": pipeline.ai_confidence_score,
            "human_verdict": pipeline.human_verdict,
            "stages": pipeline.stages
        })
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get pipeline: {str(e)}")


@router.get("/pipelines/evidence/{evidence_id}", response_model=ApiResponse[dict])
async def get_pipeline_by_evidence(
    evidence_id: str,
    query_bus: QueryBus = Depends(get_query_bus)
):
    """Get verification pipeline by evidence ID."""
    try:
        query = GetPipelineByEvidenceIdQuery(evidence_id=evidence_id)
        pipeline = await query_bus.ask(query)
        if not pipeline:
            return ApiResponse.ok({"pipeline": None, "message": "No pipeline found for this evidence"})

        return ApiResponse.ok({
            "pipeline_id": pipeline.pipeline_id,
            "evidence_id": pipeline.evidence_id,
            "task_id": pipeline.task_id,
            "submitted_by": pipeline.submitted_by,
            "status": pipeline.status.value
        })
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get pipeline by evidence: {str(e)}")


@router.get("/queue", response_model=ApiResponse[list], summary="Human review queue")
async def get_review_queue(
    query_bus: QueryBus = Depends(get_query_bus),
    limit: int = 20
):
    """Get human review queue."""
    try:
        query = GetReviewQueueQuery(limit=limit)
        pipelines = await query_bus.ask(query)

        return ApiResponse.ok([
            {
                "pipeline_id": pipeline.pipeline_id,
                "evidence_id": pipeline.evidence_id,
                "task_id": pipeline.task_id,
                "submitted_by": pipeline.submitted_by,
                "fraud_risk_score": pipeline.fraud_risk_score,
                "assigned_reviewer": pipeline.assigned_reviewer,
                "ai_confidence_score": pipeline.ai_confidence_score
            }
            for pipeline in pipelines
        ])
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get review queue: {str(e)}")


@router.get("/health", response_model=ApiResponse[dict], include_in_schema=False)
async def health_check():
    """Service health check."""
    return ApiResponse.ok(await VerificationHealthChecks.health_check())


@router.get("/health/live", response_model=ApiResponse[dict], include_in_schema=False)
async def liveness_check():
    """Service liveness check."""
    return ApiResponse.ok(await VerificationHealthChecks.liveness_check())


@router.get("/health/ready", response_model=ApiResponse[dict], include_in_schema=False)
async def readiness_check():
    """Service readiness check."""
    return ApiResponse.ok(await VerificationHealthChecks.readiness_check())
