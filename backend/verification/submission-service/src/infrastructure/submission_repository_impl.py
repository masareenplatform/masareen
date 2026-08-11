"""
PostgreSQL implementation of SubmissionRepository

Implements Event Sourcing pattern with Transactional Outbox and CQRS
"""
import json
from dataclasses import dataclass, field
from datetime import datetime
from typing import List, Optional, Any
from uuid import uuid4
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from shared.base_repository import Repository, ReadRepository
from shared.utils.outbox import OutboxWriter
from shared.utils.logging import get_logger
from ..domain.submission import SubmissionBundle, EvidenceItem, GpsLocation

log = get_logger(__name__)


class SubmissionRepositoryImpl(Repository[SubmissionBundle], ReadRepository[SubmissionBundle]):
    """
    PostgreSQL repository implementing Event Sourcing for SubmissionBundle.
    
    Maintains projection tables for efficient querying.
    Uses Transactional Outbox for event publishing.
    Supports UUID-based entity IDs.
    """
    
    def __init__(self, session: AsyncSession, outbox: OutboxWriter):
        self._session = session
        self._outbox = outbox

    async def get_by_id(self, entity_id: str) -> Optional[SubmissionBundle]:
        """Get submission bundle by ID using projection table for efficiency."""
        query = text("""
            SELECT 
                bundle_id, task_id, submitted_by, status, evidence_items, 
                gps_locations, approval_score, rejection_reason,
                created_at, submitted_at, completed_at
            FROM submission_projections
            WHERE bundle_id = :bundle_id AND deleted_at IS NULL
        """)
        result = await self._session.execute(query, {"bundle_id": entity_id})
        row = result.fetchone()
        
        if not row:
            return None
            
        return self._row_to_bundle(row)

    async def get_by_task(self, task_id: str) -> Optional[SubmissionBundle]:
        """Get submission bundle by task ID."""
        query = text("""
            SELECT 
                bundle_id, task_id, submitted_by, status, evidence_items, 
                gps_locations, approval_score, rejection_reason,
                created_at, submitted_at, completed_at
            FROM submission_projections
            WHERE task_id = :task_id AND deleted_at IS NULL
            ORDER BY created_at DESC
            LIMIT 1
        """)
        result = await self._session.execute(query, {"task_id": task_id})
        row = result.fetchone()
        
        if not row:
            return None
            
        return self._row_to_bundle(row)

    async def save(self, bundle: SubmissionBundle) -> SubmissionBundle:
        """Save submission bundle with Event Sourcing support."""
        if not bundle.id:
            bundle.id = str(uuid4())
            await self._save_new(bundle)
        else:
            await self._update(bundle)
            
        await self._update_projection(bundle)
        return bundle

    async def update(self, bundle: SubmissionBundle) -> SubmissionBundle:
        """Update existing submission bundle."""
        await self._update(bundle)
        await self._update_projection(bundle)
        return bundle

    async def delete(self, entity_id: str) -> None:
        """Soft delete submission bundle."""
        query = text("""
            UPDATE submission_projections
            SET deleted_at = NOW()
            WHERE bundle_id = :bundle_id AND deleted_at IS NULL
        """)
        await self._session.execute(query, {"bundle_id": entity_id})
        
        # Soft delete in event sourcing table
        query = text("""
            UPDATE submission_events
            SET deleted_at = NOW()
            WHERE aggregate_id = :aggregate_id AND deleted_at IS NULL
        """)
        await self._session.execute(query, {"aggregate_id": entity_id})

    async def exists(self, entity_id: str) -> bool:
        """Check if submission bundle exists."""
        query = text("""
            SELECT 1 FROM submission_projections
            WHERE bundle_id = :bundle_id AND deleted_at IS NULL
        """)
        result = await self._session.execute(query, {"bundle_id": entity_id})
        return result.fetchone() is not None

    async def list(self, limit: int = 50, offset: int = 0) -> List[SubmissionBundle]:
        """List all non-deleted submission bundles with pagination."""
        query = text("""
            SELECT
                bundle_id, task_id, submitted_by, status, evidence_items,
                gps_locations, approval_score, rejection_reason,
                created_at, submitted_at, completed_at
            FROM submission_projections
            WHERE deleted_at IS NULL
            ORDER BY created_at DESC
            LIMIT :limit OFFSET :offset
        """)
        result = await self._session.execute(query, {"limit": limit, "offset": offset})
        return [self._row_to_bundle(row) for row in result.fetchall()]

    async def get_by_submitter(self, user_id: str, limit: int = 50, offset: int = 0) -> tuple[List[SubmissionBundle], int]:
        """Get submission bundles by submitter with pagination."""
        # Get total count
        count_query = text("""
            SELECT COUNT(*) FROM submission_projections
            WHERE submitted_by = :user_id AND deleted_at IS NULL
        """)
        count_result = await self._session.execute(count_query, {"user_id": user_id})
        total_count = count_result.scalar()
        
        # Get paginated results
        list_query = text("""
            SELECT 
                bundle_id, task_id, submitted_by, status, evidence_items, 
                gps_locations, approval_score, rejection_reason,
                created_at, submitted_at, completed_at
            FROM submission_projections
            WHERE submitted_by = :user_id AND deleted_at IS NULL
            ORDER BY created_at DESC
            LIMIT :limit OFFSET :offset
        """)
        result = await self._session.execute(
            list_query, 
            {"user_id": user_id, "limit": limit, "offset": offset}
        )
        
        bundles = []
        for row in result.fetchall():
            bundles.append(self._row_to_bundle(row))
            
        return bundles, total_count

    async def publish_events(self, bundle: SubmissionBundle) -> None:
        """Publish domain events using Transactional Outbox."""
        events = bundle.pull_domain_events()
        if not events:
            return
            
        for event in events:
            await self._outbox.write(self._session, event, "submission_events")

    def _row_to_bundle(self, row) -> SubmissionBundle:
        """Convert database row to SubmissionBundle."""
        bundle_dict = {
            'id': row.bundle_id,
            'task_id': row.task_id,
            'submitted_by': row.submitted_by,
            'status': row.status,
            'evidence_items': row.evidence_items or [],
            'gps_locations': row.gps_locations or [],
            'approval_score': row.approval_score,
            'rejection_reason': row.rejection_reason,
            'created_at': row.created_at,
            'submitted_at': row.submitted_at,
            'completed_at': row.completed_at,
        }
        
        return SubmissionBundle(**bundle_dict)

    async def _save_new(self, bundle: SubmissionBundle) -> None:
        """Save new submission bundle to database."""
        query = text("""
            INSERT INTO submission_events (
                event_id, aggregate_id, event_type, event_data, version, created_at
            ) VALUES (:event_id, :aggregate_id, :event_type, :event_data::jsonb, :version, :created_at)
        """)
        await self._session.execute(query, {
            'event_id': str(uuid4()),
            'aggregate_id': bundle.id,
            'event_type': bundle.status.value + '_CREATED',
            'event_data': json.dumps(self._bundle_to_dict(bundle)),
            'version': 1,
            'created_at': datetime.utcnow()
        })

    async def _update(self, bundle: SubmissionBundle) -> None:
        """Update submission bundle in database."""
        query = text("""
            INSERT INTO submission_events (
                event_id, aggregate_id, event_type, event_data, version, created_at
            ) VALUES (:event_id, :aggregate_id, :event_type, :event_data::jsonb, :version, :created_at)
        """)
        await self._session.execute(query, {
            'event_id': str(uuid4()),
            'aggregate_id': bundle.id,
            'event_type': 'STATE_UPDATED',
            'event_data': json.dumps(self._bundle_to_dict(bundle)),
            'version': 1,
            'created_at': datetime.utcnow()
        })

    def _bundle_to_dict(self, bundle: SubmissionBundle) -> dict:
        return {
            "id": bundle.id,
            "task_id": bundle.task_id,
            "submitted_by": bundle.submitted_by,
            "status": bundle.status.value,
            "evidence_items": [
                {"evidence_id": e.evidence_id, "media_type": e.media_type,
                 "file_size_bytes": e.file_size_bytes, "checksum": e.checksum,
                 "storage_url": e.storage_url, "latitude": e.latitude,
                 "longitude": e.longitude}
                for e in bundle.evidence_items
            ],
            "gps_locations": [
                {"latitude": l.latitude, "longitude": l.longitude,
                 "accuracy_meters": l.accuracy_meters, "provider": l.provider}
                for l in bundle.gps_locations
            ],
            "approval_score": bundle.approval_score,
            "rejection_reason": bundle.rejection_reason,
            "created_at": bundle.created_at.isoformat(),
            "submitted_at": bundle.submitted_at.isoformat() if bundle.submitted_at else None,
            "completed_at": bundle.completed_at.isoformat() if bundle.completed_at else None,
        }

    async def _update_projection(self, bundle: SubmissionBundle) -> None:
        """Update projection table for efficient querying."""
        query = text("""
            INSERT INTO submission_projections (
                bundle_id, task_id, submitted_by, status, evidence_items,
                gps_locations, approval_score, rejection_reason,
                created_at, submitted_at, completed_at
            ) VALUES (
                :bundle_id, :task_id, :submitted_by, :status, :evidence_items,
                :gps_locations, :approval_score, :rejection_reason,
                :created_at, :submitted_at, :completed_at
            ) ON CONFLICT (bundle_id) DO UPDATE SET
                task_id = :task_id,
                submitted_by = :submitted_by,
                status = :status,
                evidence_items = :evidence_items,
                gps_locations = :gps_locations,
                approval_score = :approval_score,
                rejection_reason = :rejection_reason,
                created_at = :created_at,
                submitted_at = :submitted_at,
                completed_at = :completed_at,
                updated_at = NOW()
        """)
        await self._session.execute(query, {
            'bundle_id': bundle.id,
            'task_id': bundle.task_id,
            'submitted_by': bundle.submitted_by,
            'status': bundle.status.value,
            'evidence_items': str(bundle.evidence_items),
            'gps_locations': str(bundle.gps_locations),
            'approval_score': bundle.approval_score,
            'rejection_reason': bundle.rejection_reason,
            'created_at': bundle.created_at,
            'submitted_at': bundle.submitted_at,
            'completed_at': bundle.completed_at,
        })

# Alias used by the API/handlers wiring.
PostgresSubmissionRepository = SubmissionRepositoryImpl
