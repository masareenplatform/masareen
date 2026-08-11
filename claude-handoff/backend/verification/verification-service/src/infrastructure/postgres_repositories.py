"""PostgreSQL repository for verification infrastructure.

Uses SQLAlchemy async sessions (matching the shared kernel pattern).
"""
from typing import List, Optional, Tuple, Dict, Any
from uuid import uuid4
from datetime import datetime, timezone
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from shared.utils.logging import get_logger
from ..domain.evidence_record import EvidenceRecord, EvidenceStatus, FinalVerdict
from ..domain.verification_pipeline import VerificationPipeline, PipelineStatus
from shared.base_entity import OutboxEntry

log = get_logger(__name__)

# ... (rest of the file) ...

log = get_logger(__name__)


class PostgresEvidenceRepository:
    """PostgreSQL implementation of EvidenceRepository using SQLAlchemy async."""

    def __init__(self, session: AsyncSession):
        self._session = session

    async def get_by_id(self, evidence_id: str) -> Optional[EvidenceRecord]:
        query = text("SELECT * FROM evidence_records WHERE id = :id")
        result = await self._session.execute(query, {"id": evidence_id})
        row = result.fetchone()
        return self._row_to_evidence(row) if row else None

    async def save(self, evidence: EvidenceRecord) -> EvidenceRecord:
        if not evidence.id:
            evidence.id = str(uuid4())
        query = text("""
            INSERT INTO evidence_records (id, evidence_id, task_id, submitted_by,
                status, media_type, file_size_bytes, storage_url,
                thumbnail_url, checksum, latitude, longitude,
                captured_at, uploaded_at, ai_confidence_score,
                fraud_risk_score, fraud_risk_details, verifier_type,
                verified_at, final_verdict, confidence_score, notes,
                assigned_reviewer, metadata, created_at, updated_at)
            VALUES (:id, :evidence_id, :task_id, :submitted_by,
                :status, :media_type, :file_size_bytes, :storage_url,
                :thumbnail_url, :checksum, :latitude, :longitude,
                :captured_at, :uploaded_at, :ai_confidence_score,
                :fraud_risk_score, :fraud_risk_details, :verifier_type,
                :verified_at, :final_verdict, :confidence_score, :notes,
                :assigned_reviewer, :metadata::jsonb, :created_at, :updated_at)
            ON CONFLICT (id) DO UPDATE SET
                status = :status, updated_at = :updated_at,
                ai_confidence_score = :ai_confidence_score,
                fraud_risk_score = :fraud_risk_score,
                final_verdict = :final_verdict,
                confidence_score = :confidence_score,
                verified_at = :verified_at, verifier_type = :verifier_type
        """)
        await self._session.execute(query, {
            "id": evidence.id, "evidence_id": evidence.evidence_id,
            "task_id": evidence.task_id, "submitted_by": evidence.submitted_by,
            "status": evidence.status.value, "media_type": evidence.media_type,
            "file_size_bytes": evidence.file_size_bytes,
            "storage_url": evidence.storage_url,
            "thumbnail_url": evidence.thumbnail_url, "checksum": evidence.checksum,
            "latitude": evidence.latitude, "longitude": evidence.longitude,
            "captured_at": evidence.captured_at, "uploaded_at": evidence.uploaded_at,
            "ai_confidence_score": evidence.ai_confidence_score,
            "fraud_risk_score": evidence.fraud_risk_score,
            "fraud_risk_details": evidence.fraud_risk_details,
            "verifier_type": evidence.verifier_type,
            "verified_at": evidence.verified_at,
            "final_verdict": evidence.final_verdict.value if evidence.final_verdict else None,
            "confidence_score": evidence.confidence_score, "notes": evidence.notes,
            "assigned_reviewer": evidence.assigned_reviewer,
            "metadata": evidence.metadata or {},
            "created_at": evidence.created_at, "updated_at": evidence.updated_at,
        })
        return evidence

    async def list_by_task(self, task_id: str) -> List[EvidenceRecord]:
        result = await self._session.execute(
            text("SELECT * FROM evidence_records WHERE task_id = :task_id ORDER BY created_at DESC"),
            {"task_id": task_id},
        )
        return [self._row_to_evidence(row) for row in result.fetchall()]

    async def list_by_submitter(self, user_id: str, limit: int, offset: int) -> Tuple[List[EvidenceRecord], int]:
        count = await self._session.execute(
            text("SELECT COUNT(*) FROM evidence_records WHERE submitted_by = :uid"), {"uid": user_id},
        )
        total = count.scalar() or 0
        result = await self._session.execute(
            text("SELECT * FROM evidence_records WHERE submitted_by = :uid ORDER BY created_at DESC LIMIT :limit OFFSET :offset"),
            {"uid": user_id, "limit": limit, "offset": offset},
        )
        return [self._row_to_evidence(row) for row in result.fetchall()], total

    async def find_by_checksum(self, checksum: str) -> Optional[EvidenceRecord]:
        result = await self._session.execute(
            text("SELECT * FROM evidence_records WHERE checksum = :cs"), {"cs": checksum},
        )
        row = result.fetchone()
        return self._row_to_evidence(row) if row else None

    def _row_to_evidence(self, row) -> EvidenceRecord:
        return EvidenceRecord(
            id=row.id, evidence_id=row.evidence_id, task_id=row.task_id,
            submitted_by=row.submitted_by, status=EvidenceStatus(row.status),
            media_type=row.media_type, file_size_bytes=row.file_size_bytes or 0,
            storage_url=row.storage_url, thumbnail_url=row.thumbnail_url,
            checksum=row.checksum, latitude=row.latitude, longitude=row.longitude,
            captured_at=row.captured_at, uploaded_at=row.uploaded_at,
            ai_confidence_score=row.ai_confidence_score or 0.0,
            fraud_risk_score=row.fraud_risk_score or 0,
            fraud_risk_details=row.fraud_risk_details,
            verifier_type=row.verifier_type, verified_at=row.verified_at,
            final_verdict=FinalVerdict(row.final_verdict) if row.final_verdict else None,
            confidence_score=row.confidence_score or 0.0, notes=row.notes,
            assigned_reviewer=row.assigned_reviewer,
            metadata=row.metadata or {}, created_at=row.created_at, updated_at=row.updated_at,
        )


class PostgresVerificationPipelineRepository:
    """PostgreSQL implementation of VerificationPipelineRepository using SQLAlchemy async."""

    def __init__(self, session: AsyncSession):
        self._session = session

    async def get_by_id(self, pipeline_id: str) -> Optional[VerificationPipeline]:
        result = await self._session.execute(
            text("SELECT * FROM verification_pipelines WHERE id = :id"), {"id": pipeline_id},
        )
        row = result.fetchone()
        return self._row_to_pipeline(row) if row else None

    async def get_by_evidence_id(self, evidence_id: str) -> Optional[VerificationPipeline]:
        result = await self._session.execute(
            text("SELECT * FROM verification_pipelines WHERE evidence_id = :eid"), {"eid": evidence_id},
        )
        row = result.fetchone()
        return self._row_to_pipeline(row) if row else None

    async def save(self, pipeline: VerificationPipeline) -> VerificationPipeline:
        if not pipeline.id:
            pipeline.id = str(uuid4())
        query = text("""
            INSERT INTO verification_pipelines (id, pipeline_id, evidence_id, task_id,
                submitted_by, status, ai_confidence_threshold, fraud_risk_threshold,
                fraud_risk_score, fraud_risk_details, final_verdict,
                assigned_reviewer, ai_confidence_score, human_verdict,
                created_at, updated_at)
            VALUES (:id, :pipeline_id, :evidence_id, :task_id,
                :submitted_by, :status, :ai_confidence_threshold, :fraud_risk_threshold,
                :fraud_risk_score, :fraud_risk_details, :final_verdict,
                :assigned_reviewer, :ai_confidence_score, :human_verdict,
                :created_at, :updated_at)
            ON CONFLICT (id) DO UPDATE SET
                status = :status, updated_at = :updated_at,
                fraud_risk_score = :fraud_risk_score,
                fraud_risk_details = :fraud_risk_details,
                final_verdict = :final_verdict,
                ai_confidence_score = :ai_confidence_score,
                human_verdict = :human_verdict
        """)
        await self._session.execute(query, {
            "id": pipeline.id, "pipeline_id": pipeline.pipeline_id,
            "evidence_id": pipeline.evidence_id, "task_id": pipeline.task_id,
            "submitted_by": pipeline.submitted_by, "status": pipeline.status.value,
            "ai_confidence_threshold": pipeline.ai_confidence_threshold,
            "fraud_risk_threshold": pipeline.fraud_risk_threshold,
            "fraud_risk_score": pipeline.fraud_risk_score,
            "fraud_risk_details": pipeline.fraud_risk_details,
            "final_verdict": pipeline.final_verdict,
            "assigned_reviewer": pipeline.assigned_reviewer,
            "ai_confidence_score": pipeline.ai_confidence_score,
            "human_verdict": pipeline.human_verdict,
            "created_at": pipeline.created_at, "updated_at": pipeline.updated_at,
        })
        return pipeline

    async def list_pending(self) -> List[VerificationPipeline]:
        result = await self._session.execute(
            text("SELECT * FROM verification_pipelines WHERE status IN ('QUEUED', 'PROCESSING')"),
        )
        return [self._row_to_pipeline(row) for row in result.fetchall()]

    async def list_by_submitter(self, user_id: str) -> List[VerificationPipeline]:
        result = await self._session.execute(
            text("SELECT * FROM verification_pipelines WHERE submitted_by = :uid ORDER BY created_at DESC"),
            {"uid": user_id},
        )
        return [self._row_to_pipeline(row) for row in result.fetchall()]

    def _row_to_pipeline(self, row) -> VerificationPipeline:
        return VerificationPipeline(
            id=row.id, pipeline_id=row.pipeline_id, evidence_id=row.evidence_id,
            task_id=row.task_id, submitted_by=row.submitted_by,
            status=PipelineStatus(row.status),
            ai_confidence_threshold=row.ai_confidence_threshold or 0.8,
            fraud_risk_threshold=row.fraud_risk_threshold or 30,
            fraud_risk_score=row.fraud_risk_score or 0,
            fraud_risk_details=row.fraud_risk_details,
            final_verdict=row.final_verdict,
            assigned_reviewer=row.assigned_reviewer,
            ai_confidence_score=row.ai_confidence_score or 0.0,
            human_verdict=row.human_verdict,
        )

class PostgresOutboxRepository:
    """PostgreSQL implementation of the Outbox pattern."""

    def __init__(self, session: AsyncSession):
        self._session = session

    async def save(self, entry: OutboxEntry) -> None:
        query = text("""
            INSERT INTO outbox (id, aggregate_id, event_type, payload, created_at, published)
            VALUES (:id, :aggregate_id, :event_type, :payload::jsonb, :created_at, :published)
        """)
        await self._session.execute(query, {
            "id": entry.id, "aggregate_id": entry.aggregate_id,
            "event_type": entry.event_type, "payload": entry.payload,
            "created_at": entry.created_at, "published": entry.published
        })

    async def get_pending(self, limit: int = 100) -> List[OutboxEntry]:
        query = text("SELECT * FROM outbox WHERE published = FALSE ORDER BY created_at ASC LIMIT :limit")
        result = await self._session.execute(query, {"limit": limit})
        return [
            OutboxEntry(
                id=row.id, aggregate_id=row.aggregate_id, event_type=row.event_type,
                payload=row.payload, created_at=row.created_at, published=row.published,
                published_at=row.published_at
            ) for row in result.fetchall()
        ]

    async def mark_published(self, event_id: str) -> None:
        query = text("UPDATE outbox SET published = TRUE, published_at = :now WHERE id = :id")
        await self._session.execute(query, {"id": event_id, "now": datetime.now(timezone.utc)})
