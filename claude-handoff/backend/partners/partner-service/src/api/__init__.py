"""Partner / collaboration-hosting service API.

Workflow for a company or startup that wants to host a service on MASAREN
infrastructure:

    SUBMITTED  --(admin review: APPROVED)-->  APPROVED
              --(admin review: REJECTED)-->  REJECTED
    APPROVED   --(infra provisioned)------>  PROVISIONED

Every state transition is a real DB write; nothing is fabricated. If the store
is unreachable the endpoints return HTTP 503.
"""
from __future__ import annotations
from typing import Optional
from fastapi import APIRouter, status, Depends, HTTPException
from pydantic import BaseModel, Field
from shared.dtos import ApiResponse
from sqlalchemy.ext.asyncio import AsyncSession

from ..infrastructure.database import get_session
from ..infrastructure.repository import CollaborationRepository

router = APIRouter(prefix="/partners", tags=["Partners"])

VALID_STATUSES = {"SUBMITTED", "APPROVED", "REJECTED", "PROVISIONED"}
VALID_VERDICTS = {"APPROVED", "REJECTED"}


def _repo(session: AsyncSession) -> CollaborationRepository:
    return CollaborationRepository(session)


def _unavailable(exc: Exception) -> HTTPException:
    return HTTPException(status_code=503, detail="partner_store_unavailable: " + str(exc))


class SubmitCollaborationRequest(BaseModel):
    company_name: str = Field(min_length=2, max_length=160)
    contact_email: str = Field(min_length=3, max_length=254)
    website: Optional[str] = None
    service_name: str = Field(min_length=2, max_length=160)
    service_description: str = Field(min_length=10, max_length=4000)
    desired_tier: str = Field(default="SANDBOX")  # SANDBOX | STANDARD | DEDICATED
    expected_load: Optional[str] = None
    message: Optional[str] = None


class ReviewRequest(BaseModel):
    verdict: str
    reviewer_id: str
    notes: Optional[str] = None


class ProvisionRequest(BaseModel):
    provisioned_by: str
    endpoint: Optional[str] = None


@router.post("/", status_code=201, response_model=ApiResponse[dict])
async def submit_collaboration(
    body: SubmitCollaborationRequest, session: AsyncSession = Depends(get_session)
):
    try:
        data = await _repo(session).create(body.model_dump())
    except Exception as exc:
        raise _unavailable(exc)
    return ApiResponse.ok(data)


@router.get("/", response_model=ApiResponse[list])
async def list_collaborations(
    status_filter: Optional[str] = None,
    limit: int = 50,
    session: AsyncSession = Depends(get_session),
):
    try:
        rows = await _repo(session).list(status_filter, limit)
    except Exception as exc:
        raise _unavailable(exc)
    return ApiResponse.ok(rows)


@router.get("/{collab_id}", response_model=ApiResponse[dict])
async def get_collaboration(collab_id: str, session: AsyncSession = Depends(get_session)):
    try:
        row = await _repo(session).get(collab_id)
    except Exception as exc:
        raise _unavailable(exc)
    if row is None:
        return ApiResponse.error([f"Collaboration '{collab_id}' not found."])
    return ApiResponse.ok(row)


@router.patch("/{collab_id}/review", response_model=ApiResponse[dict])
async def review_collaboration(
    collab_id: str, body: ReviewRequest, session: AsyncSession = Depends(get_session)
):
    verdict = body.verdict.upper()
    if verdict not in VALID_VERDICTS:
        return ApiResponse.error([f"verdict must be one of {sorted(VALID_VERDICTS)}"])
    try:
        row = await _repo(session).review(
            collab_id, verdict, body.reviewer_id, body.notes
        )
    except Exception as exc:
        raise _unavailable(exc)
    if row is None:
        return ApiResponse.error([f"Collaboration '{collab_id}' not found."])
    return ApiResponse.ok(row)


@router.patch("/{collab_id}/provision", response_model=ApiResponse[dict])
async def provision_collaboration(
    collab_id: str, body: ProvisionRequest, session: AsyncSession = Depends(get_session)
):
    try:
        row = await _repo(session).provision(
            collab_id, body.provisioned_by, body.endpoint
        )
    except Exception as exc:
        raise _unavailable(exc)
    if row is None:
        return ApiResponse.error([f"Collaboration '{collab_id}' not found or not APPROVED."])
    return ApiResponse.ok(row)
