"""
Submission Service API â€” FastAPI routers for submission operations.

Wires the REAL event-sourced repository into the CQRS buses per-request
(mirrors the gps-service pattern), so endpoints persist/query real data
instead of dispatching into empty buses.
"""
from fastapi import APIRouter, Depends
from shared.utils.cqrs import CommandBus, QueryBus, QueryHandler
from shared.utils.logging import get_logger
from shared.utils.outbox import OutboxWriter
from shared.base_repository.db import build_engine, build_session_factory
from sqlalchemy.ext.asyncio import AsyncSession

from ..application.commands import (
    CreateSubmissionCommand,
    ValidateSubmissionCommand,
    SubmitSubmissionCommand,
    RejectSubmissionCommand,
    CreatePipelineCommand,
)
from ..application.handlers import (
    CreateSubmissionHandler,
    ValidateSubmissionHandler,
    SubmitSubmissionHandler,
    RejectSubmissionHandler,
    CreatePipelineHandler,
)
from ..infrastructure.submission_repository_impl import PostgresSubmissionRepository
from ..queries import (
    FindSubmissionsByTaskQuery,
    FindSubmissionsBySubmitterQuery,
    GetSubmissionQuery,
)
from shared.dtos import ApiResponse
from typing import List, AsyncGenerator

log = get_logger(__name__)
router = APIRouter()

engine = build_engine()
session_factory = build_session_factory(engine)


async def get_db_session() -> AsyncGenerator[AsyncSession, None]:
    async with session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


class _FindByTaskHandler(QueryHandler):
    def __init__(self, repo): self._repo = repo
    async def handle(self, q): return await self._repo.get_by_task(q.task_id) or []


class _FindBySubmitterHandler(QueryHandler):
    def __init__(self, repo): self._repo = repo
    async def handle(self, q): return await self._repo.get_by_submitter(q.user_id, q.limit, q.offset)


class _GetHandler(QueryHandler):
    def __init__(self, repo): self._repo = repo
    async def handle(self, q): return await self._repo.get_by_id(q.submission_id)


async def get_command_bus(session: AsyncSession = Depends(get_db_session)) -> CommandBus:
    bus = CommandBus()
    outbox = OutboxWriter()
    repo = PostgresSubmissionRepository(session, outbox)
    bus.register(CreateSubmissionCommand, CreateSubmissionHandler(repo, outbox, session))
    bus.register(ValidateSubmissionCommand, ValidateSubmissionHandler(repo, outbox, session))
    bus.register(SubmitSubmissionCommand, SubmitSubmissionHandler(repo, outbox, session))
    bus.register(RejectSubmissionCommand, RejectSubmissionHandler(repo, outbox, session))
    bus.register(CreatePipelineCommand, CreatePipelineHandler(repo, outbox, session))
    return bus


async def get_query_bus(session: AsyncSession = Depends(get_db_session)) -> QueryBus:
    bus = QueryBus()
    repo = PostgresSubmissionRepository(session, OutboxWriter())
    bus.register(FindSubmissionsByTaskQuery, _FindByTaskHandler(repo))
    bus.register(FindSubmissionsBySubmitterQuery, _FindBySubmitterHandler(repo))
    bus.register(GetSubmissionQuery, _GetHandler(repo))
    return bus



@router.post("/submissions")
async def create_submission(
    command: CreateSubmissionCommand,
    command_bus: CommandBus = Depends(get_command_bus)
) -> ApiResponse:
    """
    Create a new submission bundle with evidence items.
    
    - **task_id**: Task identifier from execution domain
    - **submitted_by**: User who created the submission
    - **evidence_items**: List of evidence items to include
    - **gps_locations**: Optional list of GPS locations for field validation
    """
    log.info("creating_submission", task_id=command.task_id, submitter=command.submitted_by)
    
    result = await command_bus.dispatch(command)
    log.info("submission_created_success", submission_id=result["submission_id"])
    
    return ApiResponse(
        success=True,
        data={
            "submission_id": result["submission_id"],
            "task_id": command.task_id,
            "submitted_by": command.submitted_by,
            "status": result["status"],
            "evidence_count": len(command.evidence_items),
            "created_at": result.get("created_at")
        },
        message="Submission bundle created successfully"
    )


@router.post("/submissions/{submission_id}/validate")
async def validate_submission(
    submission_id: str,
    command: ValidateSubmissionCommand,
    command_bus: CommandBus = Depends(get_command_bus)
) -> ApiResponse:
    """
    Validate submission bundle completeness and accuracy.
    
    - **submission_id**: Submission bundle identifier
    - Validates evidence integrity and GIS completeness
    - Calculates approval score based on GPS accuracy
    """
    command.submission_id = submission_id
    
    log.info("validating_submission", submission_id=submission_id)
    
    result = await command_bus.dispatch(command)
    log.info("submission_validated", submission_id=submission_id, approval_score=result.get("approval_score"))
    
    return ApiResponse(
        success=True,
        data={
            "submission_id": result["submission_id"],
            "status": result["status"],
            "approval_score": result.get("approval_score"),
            "validation_passed": result.get("approval_score", 0) >= 0.7
        },
        message=f"Submission validated with approval score: {result.get('approval_score', 0):.2f}"
    )


@router.post("/submissions/{submission_id}/submit")
async def submit_submission(
    submission_id: str,
    command: SubmitSubmissionCommand,
    command_bus: CommandBus = Depends(get_command_bus)
) -> ApiResponse:
    """
    Submit validated submission bundle for verification.
    
    - **submission_id**: Submission bundle identifier
    - Only valid submissions can be submitted
    - Creates verification pipeline after submission
    """
    command.submission_id = submission_id
    
    log.info("submitting_submission", submission_id=submission_id)
    
    result = await command_bus.dispatch(command)
    log.info("submission_submitted", submission_id=submission_id)
    
    return ApiResponse(
        success=True,
        data={
            "submission_id": result["submission_id"],
            "status": result["status"],
            "pipeline_created": True
        },
        message="Submission submitted successfully, verification pipeline created"
    )


@router.post("/submissions/{submission_id}/reject")
async def reject_submission(
    submission_id: str,
    command: RejectSubmissionCommand,
    command_bus: CommandBus = Depends(get_command_bus)
) -> ApiResponse:
    """
    Reject submission bundle with reason.
    
    - **submission_id**: Submission bundle identifier
    - **rejection_reason**: Reason for rejection
    """
    command.submission_id = submission_id
    
    log.info("rejecting_submission", submission_id=submission_id, reason=command.rejection_reason)
    
    result = await command_bus.dispatch(command)
    log.info("submission_rejected", submission_id=submission_id)
    
    return ApiResponse(
        success=True,
        data={
            "submission_id": result["submission_id"],
            "status": result["status"],
            "rejection_reason": command.rejection_reason,
            "rejected_by": "system"
        },
        message="Submission rejected"
    )


@router.post("/submissions/{submission_id}/pipeline")
async def create_verification_pipeline(
    submission_id: str,
    command: CreatePipelineCommand,
    command_bus: CommandBus = Depends(get_command_bus)
) -> ApiResponse:
    """
    Create verification pipeline for submitted bundle.
    
    - **submission_id**: Submission bundle identifier
    - Transforms bundle into verification pipeline
    - Emits PipelineCreated event for downstream services
    """
    command.submission_id = submission_id
    
    log.info("creating_pipeline", submission_id=submission_id)
    
    result = await command_bus.dispatch(command)
    log.info("pipeline_created", submission_id=submission_id)
    
    return ApiResponse(
        success=True,
        data={
            "submission_id": result["submission_id"],
            "pipeline_status": result["status"],
            "pipeline_id": result.get("pipeline_id")
        },
        message="Verification pipeline created successfully"
    )


@router.get("/submissions/tasks/{task_id}")
async def find_submissions_by_task(
    task_id: str,
    query_bus: QueryBus = Depends(get_query_bus)
) -> ApiResponse:
    """
    Find submission bundles by task ID.
    
    - **task_id**: Task identifier from execution domain
    """
    log.info("finding_submissions_by_task", task_id=task_id)

    from ..queries import FindSubmissionsByTaskQuery
    query = FindSubmissionsByTaskQuery(task_id=task_id)
    results = await query_bus.dispatch(query)
    
    return ApiResponse(
        success=True,
        data={
            "submissions": [
                {
                    "submission_id": str(bundle.id),
                    "task_id": bundle.task_id,
                    "submitted_by": bundle.submitted_by,
                    "status": bundle.status.value,
                    "evidence_count": len(bundle.evidence_items),
                    "approval_score": bundle.approval_score,
                    "created_at": bundle.created_at.isoformat()
                }
                for bundle in results
            ],
            "total_count": len(results)
        },
        message="Found submission bundles"
    )


@router.get("/submissions/users/{user_id}")
async def find_submissions_by_submitter(
    user_id: str,
    limit: int = 10,
    offset: int = 0,
    query_bus: QueryBus = Depends(get_query_bus)
) -> ApiResponse:
    """
    Find submission bundles by submitter ID with pagination.
    
    - **user_id**: User identifier
    - **limit**: Maximum number of results (default: 10)
    - **offset**: Number of records to skip (default: 0)
    """
    log.info("finding_submissions_by_user", user_id=user_id, limit=limit, offset=offset)

    from ..queries import FindSubmissionsBySubmitterQuery
    query = FindSubmissionsBySubmitterQuery(user_id=user_id, limit=limit, offset=offset)
    results, total_count = await query_bus.dispatch(query)
    
    return ApiResponse(
        success=True,
        data={
            "submissions": [
                {
                    "submission_id": str(bundle.id),
                    "task_id": bundle.task_id,
                    "submitted_by": bundle.submitted_by,
                    "status": bundle.status.value,
                    "evidence_count": len(bundle.evidence_items),
                    "approval_score": bundle.approval_score,
                    "created_at": bundle.created_at.isoformat()
                }
                for bundle in results
            ],
            "pagination": {
                "limit": limit,
                "offset": offset,
                "total_count": total_count,
                "has_more": offset + len(results) < total_count
            }
        },
        message="Found submission bundles"
    )


@router.get("/submissions/{submission_id}")
async def get_submission(
    submission_id: str,
    query_bus: QueryBus = Depends(get_query_bus)
) -> ApiResponse:
    """
    Get submission bundle by ID.
    
    - **submission_id**: Submission bundle identifier
    """
    log.info("getting_submission", submission_id=submission_id)

    from ..queries import GetSubmissionQuery
    query = GetSubmissionQuery(submission_id=submission_id)
    bundle = await query_bus.dispatch(query)
    
    if not bundle:
        return ApiResponse(
            success=False,
            data=None,
            message="Submission not found"
        )
    
    return ApiResponse(
        success=True,
        data={
            "submission_id": str(bundle.id),
            "task_id": bundle.task_id,
            "submitted_by": bundle.submitted_by,
            "status": bundle.status.value,
            "evidence_items": [
                {
                    "evidence_id": item.evidence_id,
                    "media_type": item.media_type,
                    "file_size_bytes": item.file_size_bytes,
                    "checksum": item.checksum,
                    "storage_url": item.storage_url,
                    "latitude": item.latitude,
                    "longitude": item.longitude
                }
                for item in bundle.evidence_items
            ],
            "gps_locations": [
                {
                    "latitude": loc.latitude,
                    "longitude": loc.longitude,
                    "accuracy_meters": loc.accuracy_meters,
                    "provider": loc.provider
                }
                for loc in bundle.gps_locations
            ],
            "approval_score": bundle.approval_score,
            "rejection_reason": bundle.rejection_reason,
            "submitted_at": bundle.submitted_at.isoformat() if bundle.submitted_at else None,
            "completed_at": bundle.completed_at.isoformat() if bundle.completed_at else None,
            "created_at": bundle.created_at.isoformat()
        },
        message="Submission details retrieved"
    )

