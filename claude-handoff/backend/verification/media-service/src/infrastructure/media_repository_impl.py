"""
Media repository PostgreSQL implementation.

Implements Event Sourcing pattern with Transactional Outbox and CQRS.
Maintains projection tables for efficient querying.
Uses UUID-based entity IDs.
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
from ..events.media_events import MediaUploaded
from ..domain.media_asset import MediaAsset

log = get_logger(__name__)


class MediaRepositoryImpl(Repository[MediaAsset], ReadRepository[MediaAsset]):
    """PostgreSQL repository implementing Event Sourcing for MediaAsset.
    
    Maintains projection tables for efficient querying.
    Uses Transactional Outbox for event publishing.
    Supports UUID-based entity IDs.
    """
    
    def __init__(self, session: AsyncSession, outbox: OutboxWriter):
        self._session = session
        self._outbox = outbox

    async def get_by_id(self, entity_id: str) -> Optional[MediaAsset]:
        """Get media asset by ID using projection table for efficiency."""
        query = text("""
            SELECT 
                media_asset_id, owner_id, submission_id, media_id,
                media_type, mime_type, file_size_bytes, 
                original_filename, storage_key, cdn_url, thumbnail_url,
                processing_status, checksum_sha256, width, height,
                duration_seconds, metadata, created_at, updated_at, version
            FROM media_asset_projections
            WHERE media_asset_id = :media_asset_id AND deleted_at IS NULL
        """)
        result = await self._session.execute(query, {"media_asset_id": entity_id})
        row = result.fetchone()
        
        if not row:
            return None
            
        return self._row_to_asset(row)

    async def get_by_submission(self, submission_id: str) -> List[MediaAsset]:
        """Get media assets by submission ID."""
        query = text("""
            SELECT 
                media_asset_id, owner_id, submission_id, media_id,
                media_type, mime_type, file_size_bytes, 
                original_filename, storage_key, cdn_url, thumbnail_url,
                processing_status, checksum_sha256, width, height,
                duration_seconds, metadata, created_at, updated_at, version
            FROM media_asset_projections
            WHERE submission_id = :submission_id AND deleted_at IS NULL
        """)
        result = await self._session.execute(query, {"submission_id": submission_id})
        rows = result.fetchall()
        
        assets = []
        for row in rows:
            assets.append(self._row_to_asset(row))
            
        return assets

    async def get_by_owner(self, owner_id: str, limit: int = 50, offset: int = 0) -> tuple[List[MediaAsset], int]:
        """Get media assets by owner with pagination."""
        # Get total count
        count_query = text("""
            SELECT COUNT(*) FROM media_asset_projections
            WHERE owner_id = :owner_id AND deleted_at IS NULL
        """)
        count_result = await self._session.execute(count_query, {"owner_id": owner_id})
        total_count = count_result.scalar()
        
        # Get paginated results
        list_query = text("""
            SELECT 
                media_asset_id, owner_id, submission_id, media_id,
                media_type, mime_type, file_size_bytes, 
                original_filename, storage_key, cdn_url, thumbnail_url,
                processing_status, checksum_sha256, width, height,
                duration_seconds, metadata, created_at, updated_at, version
            FROM media_asset_projections
            WHERE owner_id = :owner_id AND deleted_at IS NULL
            ORDER BY created_at DESC
            LIMIT :limit OFFSET :offset
        """)
        result = await self._session.execute(
            list_query, 
            {"owner_id": owner_id, "limit": limit, "offset": offset}
        )
        
        assets = []
        for row in result.fetchall():
            assets.append(self._row_to_asset(row))
            
        return assets, total_count

    async def get_by_checksum(self, checksum: str) -> Optional[MediaAsset]:
        """Get media asset by checksum."""
        from shared.domain.media_asset import Checksum
        checkum_obj = Checksum(value=checksum)
        
        query = text("""
            SELECT 
                media_asset_id, owner_id, submission_id, media_id,
                media_type, mime_type, file_size_bytes, 
                original_filename, storage_key, cdn_url, thumbnail_url,
                processing_status, checksum_sha256, width, height,
                duration_seconds, metadata, created_at, updated_at, version
            FROM media_asset_projections
            WHERE checksum_sha256 = :checksum AND deleted_at IS NULL
        """)
        result = await self._session.execute(query, {"checksum": checksum})
        row = result.fetchone()
        
        if not row:
            return None
            
        return self._row_to_asset(row)

    async def save(self, asset: MediaAsset) -> MediaAsset:
        """Save media asset with Event Sourcing support."""
        if not asset.id:
            asset.id = str(uuid4())
            await self._save_new(asset)
        else:
            await self._update(asset)
            
        await self._update_projection(asset)
        return asset

    async def update(self, asset: MediaAsset) -> MediaAsset:
        """Update existing media asset."""
        await self._update(asset)
        await self._update_projection(asset)
        return asset

    async def delete(self, entity_id: str) -> None:
        """Soft delete media asset."""
        query = text("""
            UPDATE media_asset_projections
            SET deleted_at = NOW()
            WHERE media_asset_id = :media_asset_id AND deleted_at IS NULL
        """)
        await self._session.execute(query, {"media_asset_id": entity_id})
        
        # Soft delete in event sourcing table
        query = text("""
            UPDATE media_asset_events
            SET deleted_at = NOW()
            WHERE aggregate_id = :aggregate_id AND deleted_at IS NULL
        """)
        await self._session.execute(query, {"aggregate_id": entity_id})

    async def exists(self, entity_id: str) -> bool:
        """Check if media asset exists."""
        query = text("""
            SELECT 1 FROM media_asset_projections
            WHERE media_asset_id = :media_asset_id AND deleted_at IS NULL
        """)
        result = await self._session.execute(query, {"media_asset_id": entity_id})
        return result.fetchone() is not None

    async def publish_events(self, asset: MediaAsset) -> None:
        """Publish domain events using Transactional Outbox."""
        events = asset.pull_domain_events()
        if not events:
            return
            
        for event in events:
            await self._outbox.write(self._session, event, "media_asset_events")

    def _row_to_asset(self, row) -> MediaAsset:
        """Convert database row to MediaAsset."""
        from ..domain.media_asset import MediaAsset

        asset_dict = {
            'id': row.media_asset_id,
            'owner_id': row.owner_id,
            'submission_id': row.submission_id,
            'mime_type': str(row.mime_type) if row.mime_type else '',
            'file_size_bytes': row.file_size_bytes,
            'original_filename': row.original_filename,
            'storage_key': row.storage_key,
            'cdn_url': row.cdn_url,
            'thumbnail_url': row.thumbnail_url,
            'processing_status': str(row.processing_status) if row.processing_status else '',
            'checksum_sha256': row.checksum_sha256,
            'width': row.width,
            'height': row.height,
            'duration_seconds': row.duration_seconds,
            'metadata': row.metadata or {},
            'created_at': row.created_at,
            'updated_at': row.updated_at,
            'version': row.version,
        }

        return MediaAsset(**asset_dict)

    async def _save_new(self, asset: MediaAsset) -> None:
        """Save new media asset to database."""
        query = text("""
            INSERT INTO media_asset_events (
                event_id, aggregate_id, event_type, event_data, version, created_at
            ) VALUES (:event_id, :aggregate_id, :event_type, :event_data, :version, :created_at)
        """)
        import json
        await self._session.execute(query, {
            'event_id': str(uuid4()),
            'aggregate_id': asset.id,
            'event_type': asset.processing_status.value + '_CREATED',
            'event_data': json.dumps(self._asset_to_dict(asset)),
            'version': 1,
            'created_at': datetime.utcnow()
        })

    async def _update(self, asset: MediaAsset) -> None:
        """Update media asset in database."""
        import json
        query = text("""
            INSERT INTO media_asset_events (
                event_id, aggregate_id, event_type, event_data, version, created_at
            ) VALUES (:event_id, :aggregate_id, :event_type, :event_data::jsonb, :version, :created_at)
        """)
        await self._session.execute(query, {
            'event_id': str(uuid4()),
            'aggregate_id': asset.id,
            'event_type': 'STATE_UPDATED',
            'event_data': json.dumps(self._asset_to_dict(asset)),
            'version': 1,
            'created_at': datetime.utcnow()
        })

    def _asset_to_dict(self, asset: MediaAsset) -> dict:
        return {
            "id": asset.id,
            "owner_id": asset.owner_id,
            "evidence_id": asset.evidence_id,
            "mime_type": asset.mime_type,
            "file_size_bytes": asset.file_size_bytes,
            "original_filename": asset.original_filename,
            "storage_key": asset.storage_key,
            "cdn_url": asset.cdn_url,
            "thumbnail_url": asset.thumbnail_url,
            "processing_status": asset.processing_status.value,
            "checksum_sha256": asset.checksum_sha256,
            "width": asset.width,
            "height": asset.height,
            "duration_seconds": asset.duration_seconds,
            "metadata": asset.metadata,
            "created_at": asset.created_at.isoformat(),
            "updated_at": asset.updated_at.isoformat(),
        }

    async def _update_projection(self, asset: MediaAsset) -> None:
        """Update projection table for efficient querying."""
        query = text("""
            INSERT INTO media_asset_projections (
                media_asset_id, owner_id, submission_id, media_id,
                media_type, mime_type, file_size_bytes, 
                original_filename, storage_key, cdn_url, thumbnail_url,
                processing_status, checksum_sha256, width, height,
                duration_seconds, metadata, created_at, updated_at, version
            ) VALUES (
                :media_asset_id, :owner_id, :submission_id, :media_id,
                :media_type, :mime_type, :file_size_bytes, 
                :original_filename, :storage_key, :cdn_url, :thumbnail_url,
                :processing_status, :checksum_sha256, :width, :height,
                :duration_seconds, :metadata, :created_at, :updated_at, :version
            ) ON CONFLICT (media_asset_id) DO UPDATE SET
                owner_id = :owner_id,
                submission_id = :submission_id,
                media_id = :media_id,
                media_type = :media_type,
                mime_type = :mime_type,
                file_size_bytes = :file_size_bytes,
                original_filename = :original_filename,
                storage_key = :storage_key,
                cdn_url = :cdn_url,
                thumbnail_url = :thumbnail_url,
                processing_status = :processing_status,
                checksum_sha256 = :checksum_sha256,
                width = :width,
                height = :height,
                duration_seconds = :duration_seconds,
                metadata = :metadata,
                updated_at = NOW()
        """)
        await self._session.execute(query, {
            'media_asset_id': asset.id,
            'owner_id': asset.owner_id,
            'submission_id': "",
            'media_id': str(asset.id),
            'media_type': asset.mime_type.split("/")[0].upper() if "/" in asset.mime_type else "UNKNOWN",
            'mime_type': str(asset.mime_type),
            'file_size_bytes': asset.file_size_bytes,
            'original_filename': asset.original_filename or "",
            'storage_key': asset.storage_key or "",
            'cdn_url': asset.cdn_url or "",
            'thumbnail_url': asset.thumbnail_url or "",
            'processing_status': asset.processing_status.value,
            'checksum_sha256': str(asset.checksum_sha256) if asset.checksum_sha256 else None,
            'width': asset.width,
            'height': asset.height,
            'duration_seconds': asset.duration_seconds,
            'metadata': asset.metadata,
            'created_at': asset.created_at,
            'updated_at': asset.updated_at,
            'version': asset.version,
        })
