"""Real collaboration repository, persists hosting requests and their lifecycle.

State machine (enforced in SQL via the CHECK constraint and guarded in Python):
    SUBMITTED -> APPROVED | REJECTED -> (APPROVED) PROVISIONED
"""
from __future__ import annotations
from typing import Optional
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession


class CollaborationRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def create(self, payload: dict) -> dict:
        row = (
            await self._session.execute(
                text(
                    """
                    INSERT INTO collaborations
                        (company_name, contact_email, website, service_name,
                         service_description, desired_tier, expected_load, message, status)
                    VALUES
                        (:company_name, :contact_email, :website, :service_name,
                         :service_description, :desired_tier, :expected_load, :message, 'SUBMITTED')
                    RETURNING *
                    """
                ),
                payload,
            )
        ).mappings().first()
        await self._session.commit()
        return dict(row)

    async def list(self, status_filter: Optional[str], limit: int) -> list:
        if status_filter:
            rows = (
                await self._session.execute(
                    text(
                        "SELECT * FROM collaborations WHERE status = :s "
                        "ORDER BY created_at DESC LIMIT :lim"
                    ),
                    {"s": status_filter, "lim": limit},
                )
            ).mappings().all()
        else:
            rows = (
                await self._session.execute(
                    text("SELECT * FROM collaborations ORDER BY created_at DESC LIMIT :lim"),
                    {"lim": limit},
                )
            ).mappings().all()
        return [dict(r) for r in rows]

    async def get(self, collab_id: str) -> Optional[dict]:
        row = (
            await self._session.execute(
                text("SELECT * FROM collaborations WHERE id = :id"), {"id": collab_id}
            )
        ).mappings().first()
        return dict(row) if row else None

    async def review(self, collab_id: str, verdict: str, reviewer_id: str, notes: Optional[str]) -> Optional[dict]:
        new_status = "APPROVED" if verdict == "APPROVED" else "REJECTED"
        row = (
            await self._session.execute(
                text(
                    """
                    UPDATE collaborations
                       SET status = :status,
                           reviewer_id = :reviewer,
                           review_notes = :notes,
                           reviewed_at = NOW()
                     WHERE id = :id AND status = 'SUBMITTED'
                    RETURNING *
                    """
                ),
                {"status": new_status, "reviewer": reviewer_id, "notes": notes, "id": collab_id},
            )
        ).mappings().first()
        await self._session.commit()
        return dict(row) if row else None

    async def provision(self, collab_id: str, provisioned_by: str, endpoint: Optional[str]) -> Optional[dict]:
        row = (
            await self._session.execute(
                text(
                    """
                    UPDATE collaborations
                       SET status = 'PROVISIONED',
                           provisioned_by = :pby,
                           endpoint = :ep,
                           provisioned_at = NOW()
                     WHERE id = :id AND status = 'APPROVED'
                    RETURNING *
                    """
                ),
                {"pby": provisioned_by, "ep": endpoint, "id": collab_id},
            )
        ).mappings().first()
        await self._session.commit()
        return dict(row) if row else None
