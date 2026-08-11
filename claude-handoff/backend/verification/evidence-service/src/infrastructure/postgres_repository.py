"""
PostgreSQL repository implementing Event Sourcing for Evidence entity.

Maintains projection tables for efficient querying.
Uses Transactional Outbox for event publishing.
"""
from dataclasses import dataclass
from datetime import datetime
from typing import List, Optional, Any
from uuid import uuid4
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from shared.base_repository import Repository, ReadRepository
from shared.utils.outbox import OutboxWriter
from shared.utils.logging import get_logger
from ..domain.evidence import Evidence, EvidenceStatus
from shared.events.verification_events import EvidenceCaptured, EvidenceUploaded, EvidenceVerified

log = get_logger(__name__)


class PostgresEvidenceRepository(Repository[Evidence], ReadRepository[Evidence]):
    """
    PostgreSQL repository implementing Event Sourcing for Evidence.
    
    Maintains projection tables for efficient querying.
    Uses Transactional Outbox for event publishing.
    """
    
    def __init__(self, session: AsyncSession, outbox: OutboxWriter):
        self._session = session
        self._outbox = outbox

    async def get_by_id(self, entity_id: str) -> Optional[Evidence]:
        """Get evidence by ID using projection table for efficiency."""
        query = text("""
            SELECT 
                evidence_id, task_id, submitted_by, status, media_type,
                storage_url, thumbnail_url, file_size_bytes, checksum,
                mime_type, latitude, longitude, captured_at, uploaded_at,
                created_at, updated_at, verifications, metadata
            FROM evidence_projections
            WHERE evidence_id = :evidence_id AND deleted_at IS NULL
        """)
        result = await self._session.execute(query, {"evidence_id": entity_id})
        row = result.fetchone()
        
        if not row:
            return None
            
        return self._row_to_evidence(row)

    async def save(self, evidence: Evidence) -> Evidence:
        """Save evidence with Event Sourcing support."""
        if not evidence.id:
            evidence.id = str(uuid4())
            await self._save_new(evidence)
        else:
            await self._update(evidence)
            
        await self._update_projection(evidence)
        return evidence

    async def update(self, evidence: Evidence) -> Evidence:
        """Update existing evidence."""
        await self._update(evidence)
        await self._update_projection(evidence)
        return evidence

    async def delete(self, entity_id: str) -> None:
        """Soft delete evidence."""
        query = text("""
            UPDATE evidence_projections
            SET deleted_at = NOW()
            WHERE evidence_id = :evidence_id AND deleted_at IS NULL
        """)
        await self._session.execute(query, {"evidence_id": entity_id})

    async def find_by_checksum(self, checksum: str) -> Optional[Evidence]:
        """Find evidence by checksum for fraud detection."""
        query = text("""
            SELECT 
                evidence_id, task_id, submitted_by, status, media_type,
                storage_url, thumbnail_url, file_size_bytes, checksum,
                mime_type, latitude, longitude, captured_at, uploaded_at,
                created_at, updated_at, verifications, metadata
            FROM evidence_projections
            WHERE checksum = :checksum AND deleted_at IS NULL
            LIMIT 1
        """)
        result = await self._session.execute(query, {"checksum": checksum})
        row = result.fetchone()
        
        if not row:
            return None
            
        return self._row_to_evidence(row)

    def _row_to_evidence(self, row) -> Evidence:
        """Convert database row to Evidence."""
        # Parse verifications from JSON string
        from shared.utils.json_utils import json_loads
        verifications_data = json_loads(row.verifications) if row.verifications else []
        
        evidence_dict = {
            'id': row.evidence_id,
            'task_id': row.task_id,
            'submitted_by': row.submitted_by,
            'media_type': row.media_type,
            'status': EvidenceStatus(row.status),
            'storage_url': row.storage_url,
            'thumbnail_url': row.thumbnail_url,
            'file_size_bytes': row.file_size_bytes,
            'checksum': row.checksum,
            'mime_type': row.mime_type,
            'latitude': row.latitude,
            'longitude': row.longitude,
            'captured_at': row.captured_at,
            'uploaded_at': row.uploaded_at,
            'created_at': row.created_at,
            'updated_at': row.updated_at,
            'verifications': verifications_data,
            'metadata': row.metadata or {},
        }
        
        return Evidence(**evidence_dict)

    async def _save_new(self, evidence: Evidence) -> None:
        """Save new evidence to database."""
        query = text("""
            INSERT INTO evidence_events (
                event_id, aggregate_id, event_type, event_data, version, created_at
            ) VALUES (:event_id, :aggregate_id, :event_type, :event_data, :version, :created_at)
        """)
        await self._session.execute(query, {
            'event_id': str(uuid4()),
            'aggregate_id': evidence.id,
            'event_type': 'EVIDENCE_CREATED',
            'event_data': evidence.to_dict(),
            'version': 1,
            'created_at': datetime.utcnow()
        })

    async def _update(self, evidence: Evidence) -> None:
        """Update evidence in database."""
        query = text("""
            INSERT INTO evidence_events (
                event_id, aggregate_id, event_type, event_data, version, created_at
            ) VALUES (:event_id, :aggregate_id, :event_type, :event_data, :version, :created_at)
        """)
        await self._session.execute(query, {
            'event_id': str(uuid4()),
            'aggregate_id': evidence.id,
            'event_type': 'STATE_UPDATED',
            'event_data': evidence.to_dict(),
            'version': 1,
            'created_at': datetime.utcnow()
        })

    async def _update_projection(self, evidence: Evidence) -> None:
        """Update projection table for efficient querying."""
        query = text("""
            INSERT INTO evidence_projections (
                evidence_id, task_id, submitted_by, status, media_type,
                storage_url, thumbnail_url, file_size_bytes, checksum,
                mime_type, latitude, longitude, captured_at, uploaded_at,
                created_at, updated_at, verifications, metadata
            ) VALUES (
                :evidence_id, :task_id, :submitted_by, :status, :media_type,
                :storage_url, :thumbnail_url, :file_size_bytes, :checksum,
                :mime_type, :latitude, :longitude, :captured_at, :uploaded_at,
                :created_at, :updated_at, :verifications, :metadata
            ) ON CONFLICT (evidence_id) DO UPDATE SET
                task_id = :task_id,
                submitted_by = :submitted_by,
                status = :status,
                media_type = :media_type,
                storage_url = :storage_url,
                thumbnail_url = :thumbnail_url,
                file_size_bytes = :file_size_bytes,
                checksum = :checksum,
                mime_type = :mime_type,
                latitude = :latitude,
                longitude = :longitude,
                captured_at = :captured_at,
                uploaded_at = :uploaded_at,
                updated_at = NOW(),
                verifications = :verifications,
                metadata = :metadata
        """)
        await self._session.execute(query, {
            'evidence_id': evidence.id,
            'task_id': evidence.task_id,
            'submitted_by': evidence.submitted_by,
            'status': evidence.status.value,
            'media_type': evidence.media_type.value,
            'storage_url': evidence.storage_url,
            'thumbnail_url': evidence.thumbnail_url,
            'file_size_bytes': evidence.file_size_bytes,
            'checksum': evidence.checksum,
            'mime_type': evidence.mime_type,
            'latitude': evidence.latitude,
            'longitude': evidence.longitude,
            'captured_at': evidence.captured_at,
            'uploaded_at': evidence.uploaded_at,
            'created_at': evidence.created_at,
            'updated_at': evidence.updated_at,
            'verifications': str(evidence.verifications),
            'metadata': evidence.metadata,
        })
