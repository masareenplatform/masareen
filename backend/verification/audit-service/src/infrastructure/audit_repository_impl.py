"""PostgreSQL implementation of AuditRepository.

Append-only table ensures immutability.
No UPDATE or DELETE operations, only INSERT and SELECT.
"""
from typing import List, Optional
from uuid import uuid4
from datetime import datetime
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from shared.utils.logging import get_logger
from shared.base_entity import AggregateRoot
from ..domain.audit_record import AuditRecord
from ..domain.audit_repository import AuditRepository

log = get_logger(__name__)


class PostgresAuditRepository(AuditRepository):
    """PostgreSQL audit repository, append-only, no updates or deletes."""

    def __init__(self, session: AsyncSession):
        self._session = session

    async def save(self, record: AuditRecord) -> AuditRecord:
        if not record.id:
            record.id = str(uuid4())
        query = text("""
            INSERT INTO audit_events (
                event_id, event_type, aggregate_type, aggregate_id,
                actor_id, action, details, source_service,
                created_at
            ) VALUES (
                :event_id, :event_type, :aggregate_type, :aggregate_id,
                :actor_id, :action, :details::jsonb, :source_service,
                :created_at
            )
        """)
        await self._session.execute(query, {
            "event_id": record.id,
            "event_type": record.event_type.value,
            "aggregate_type": record.aggregate_type,
            "aggregate_id": record.aggregate_id,
            "actor_id": record.actor_id,
            "action": record.action,
            "details": record.details,
            "source_service": record.source_service,
            "created_at": record.created_at or datetime.utcnow(),
        })
        return record

    async def get_by_id(self, record_id: str) -> Optional[AuditRecord]:
        query = text("""
            SELECT event_id, event_type, aggregate_type, aggregate_id,
                   actor_id, action, details, source_service, created_at
            FROM audit_events
            WHERE event_id = :event_id
        """)
        result = await self._session.execute(query, {"event_id": record_id})
        row = result.fetchone()
        return self._row_to_record(row) if row else None

    async def list_by_aggregate(self, aggregate_id: str) -> List[AuditRecord]:
        query = text("""
            SELECT event_id, event_type, aggregate_type, aggregate_id,
                   actor_id, action, details, source_service, created_at
            FROM audit_events
            WHERE aggregate_id = :aggregate_id
            ORDER BY created_at ASC
        """)
        result = await self._session.execute(query, {"aggregate_id": aggregate_id})
        return [self._row_to_record(row) for row in result.fetchall()]

    async def list_by_actor(self, actor_id: str, limit: int = 50, offset: int = 0) -> tuple[List[AuditRecord], int]:
        count = await self._session.execute(
            text("SELECT COUNT(*) FROM audit_events WHERE actor_id = :actor_id"),
            {"actor_id": actor_id},
        )
        total = count.scalar() or 0
        result = await self._session.execute(
            text("""SELECT event_id, event_type, aggregate_type, aggregate_id,
                     actor_id, action, details, source_service, created_at
                    FROM audit_events WHERE actor_id = :actor_id
                    ORDER BY created_at DESC LIMIT :limit OFFSET :offset"""),
            {"actor_id": actor_id, "limit": limit, "offset": offset},
        )
        return [self._row_to_record(row) for row in result.fetchall()], total

    async def list_by_event_type(self, event_type: str, limit: int = 50, offset: int = 0) -> tuple[List[AuditRecord], int]:
        count = await self._session.execute(
            text("SELECT COUNT(*) FROM audit_events WHERE event_type = :event_type"),
            {"event_type": event_type},
        )
        total = count.scalar() or 0
        result = await self._session.execute(
            text("""SELECT event_id, event_type, aggregate_type, aggregate_id,
                     actor_id, action, details, source_service, created_at
                    FROM audit_events WHERE event_type = :event_type
                    ORDER BY created_at DESC LIMIT :limit OFFSET :offset"""),
            {"event_type": event_type, "limit": limit, "offset": offset},
        )
        return [self._row_to_record(row) for row in result.fetchall()], total

    async def list_all(self, limit: int = 50, offset: int = 0) -> tuple[List[AuditRecord], int]:
        count = await self._session.execute(text("SELECT COUNT(*) FROM audit_events"))
        total = count.scalar() or 0
        result = await self._session.execute(
            text("""SELECT event_id, event_type, aggregate_type, aggregate_id,
                     actor_id, action, details, source_service, created_at
                    FROM audit_events ORDER BY created_at DESC LIMIT :limit OFFSET :offset"""),
            {"limit": limit, "offset": offset},
        )
        return [self._row_to_record(row) for row in result.fetchall()], total

    def _row_to_record(self, row) -> AuditRecord:
        from ..domain.audit_record import AuditEventType
        event_type_str = row.event_type
        try:
            event_type = AuditEventType(event_type_str)
        except ValueError:
            event_type = AuditEventType.SUBMISSION_CREATED

        return AuditRecord(
            id=row.event_id,
            event_type=event_type,
            aggregate_type=row.aggregate_type,
            aggregate_id=row.aggregate_id,
            actor_id=row.actor_id,
            action=row.action,
            details=row.details or {},
            source_service=row.source_service,
            created_at=row.created_at,
        )
