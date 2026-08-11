"""GPS PostgreSQL Repository implementation."""
import json
from dataclasses import dataclass
from datetime import datetime
from typing import List, Optional, Any
from uuid import uuid4
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from shared.base_repository import Repository, ReadRepository
from shared.utils.outbox import OutboxWriter
from shared.utils.logging import get_logger
from ..domain.gps_record import GPSRecord

log = get_logger(__name__)


class PostgresGPSRepository(Repository[GPSRecord], ReadRepository[GPSRecord]):
    def __init__(self, session: AsyncSession, outbox: OutboxWriter):
        self._session = session
        self._outbox = outbox

    async def get_by_id(self, entity_id: str) -> Optional[GPSRecord]:
        query = text("""
            SELECT gps_id, task_id, submitted_by, status, media_type,
                   storage_url, thumbnail_url, file_size_bytes, checksum,
                   mime_type, latitude, longitude, captured_at, uploaded_at,
                   created_at, updated_at, verifications, metadata
            FROM gps_projections
            WHERE gps_id = :gps_id AND deleted_at IS NULL
        """)
        result = await self._session.execute(query, {"gps_id": entity_id})
        row = result.fetchone()

        if not row:
            return None

        return self._row_to_gps(row)

    async def save(self, gps_record: GPSRecord) -> GPSRecord:
        if not gps_record.id:
            gps_record.id = str(uuid4())
            await self._save_new(gps_record)
        else:
            await self._update(gps_record)

        await self._update_projection(gps_record)
        return gps_record

    async def find_by_checksum(self, checksum: str) -> Optional[GPSRecord]:
        query = text("""
            SELECT gps_id, task_id, submitted_by, status, media_type,
                   storage_url, thumbnail_url, file_size_bytes, checksum,
                   mime_type, latitude, longitude, captured_at, uploaded_at,
                   created_at, updated_at, verifications, metadata
            FROM gps_projections
            WHERE checksum = :checksum AND deleted_at IS NULL
            LIMIT 1
        """)
        result = await self._session.execute(query, {"checksum": checksum})
        row = result.fetchone()

        if not row:
            return None

        return self._row_to_gps(row)

    async def find_by_task_id(self, task_id: str) -> List[GPSRecord]:
        query = text("""
            SELECT gps_id, task_id, submitted_by, status, media_type,
                   storage_url, thumbnail_url, file_size_bytes, checksum,
                   mime_type, latitude, longitude, captured_at, uploaded_at,
                   created_at, updated_at, verifications, metadata
            FROM gps_projections
            WHERE task_id = :task_id AND deleted_at IS NULL
        """)
        result = await self._session.execute(query, {"task_id": task_id})
        rows = result.fetchall()

        return [self._row_to_gps(row) for row in rows]

    async def find_by_user_id(self, user_id: str) -> List[GPSRecord]:
        query = text("""
            SELECT gps_id, task_id, submitted_by, status, media_type,
                   storage_url, thumbnail_url, file_size_bytes, checksum,
                   mime_type, latitude, longitude, captured_at, uploaded_at,
                   created_at, updated_at, verifications, metadata
            FROM gps_projections
            WHERE submitted_by = :user_id AND deleted_at IS NULL
            ORDER BY created_at DESC
            LIMIT :limit
        """)
        result = await self._session.execute(query, {"user_id": user_id, "limit": 50})
        rows = result.fetchall()

        return [self._row_to_gps(row) for row in rows]

    async def update(self, gps_record: GPSRecord) -> GPSRecord:
        await self._update(gps_record)
        await self._update_projection(gps_record)
        return gps_record

    async def delete(self, entity_id: str) -> None:
        query = text("""
            UPDATE gps_projections
            SET deleted_at = NOW()
            WHERE gps_id = :gps_id AND deleted_at IS NULL
        """)
        await self._session.execute(query, {"gps_id": entity_id})

    async def exists(self, entity_id: str) -> bool:
        query = text("SELECT 1 FROM gps_projections WHERE gps_id = :gps_id AND deleted_at IS NULL")
        result = await self._session.execute(query, {"gps_id": entity_id})
        return result.fetchone() is not None

    async def list(self, limit: int = 50, offset: int = 0) -> list[GPSRecord]:
        query = text("""
            SELECT * FROM gps_projections
            WHERE deleted_at IS NULL
            ORDER BY created_at DESC
            LIMIT :limit OFFSET :offset
        """)
        result = await self._session.execute(query, {"limit": limit, "offset": offset})
        return [self._row_to_gps(row) for row in result.fetchall()]

    def _row_to_gps(self, row) -> GPSRecord:
        import json
        verifications_data = json.loads(row.verifications) if row.verifications else []

        gps_dict = {
            'id': row.gps_id,
            'task_id': row.task_id,
            'submitted_by': row.submitted_by,
            'media_type': row.media_type,
            'status': row.status,
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

        return GPSRecord(**gps_dict)

    def _gps_to_dict(self, gps_record: GPSRecord) -> str:
        return json.dumps({
            "id": gps_record.id,
            "task_id": gps_record.task_id,
            "submitted_by": gps_record.submitted_by,
            "media_type": gps_record.media_type.value if gps_record.media_type else None,
            "status": gps_record.status.value if gps_record.status else None,
            "storage_url": gps_record.storage_url,
            "thumbnail_url": gps_record.thumbnail_url,
            "file_size_bytes": gps_record.file_size_bytes,
            "checksum": gps_record.checksum,
            "latitude": gps_record.latitude,
            "longitude": gps_record.longitude,
        })

    async def _save_new(self, gps_record: GPSRecord) -> None:
        query = text("""
            INSERT INTO gps_events (
                event_id, aggregate_id, event_type, event_data, version, created_at
            ) VALUES (:event_id, :aggregate_id, :event_type, :event_data::jsonb, :version, :created_at)
        """)
        await self._session.execute(query, {
            'event_id': str(uuid4()),
            'aggregate_id': gps_record.id,
            'event_type': 'GPS_CREATED',
            'event_data': self._gps_to_dict(gps_record),
            'version': 1,
            'created_at': datetime.utcnow()
        })

    async def _update(self, gps_record: GPSRecord) -> None:
        query = text("""
            INSERT INTO gps_events (
                event_id, aggregate_id, event_type, event_data, version, created_at
            ) VALUES (:event_id, :aggregate_id, :event_type, :event_data::jsonb, :version, :created_at)
        """)
        await self._session.execute(query, {
            'event_id': str(uuid4()),
            'aggregate_id': gps_record.id,
            'event_type': 'STATE_UPDATED',
            'event_data': self._gps_to_dict(gps_record),
            'version': 1,
            'created_at': datetime.utcnow()
        })

    async def _update_projection(self, gps_record: GPSRecord) -> None:
        query = text("""
            INSERT INTO gps_projections (
                gps_id, task_id, submitted_by, status, media_type,
                storage_url, thumbnail_url, file_size_bytes, checksum,
                mime_type, latitude, longitude, captured_at, uploaded_at,
                created_at, updated_at, verifications, metadata
            ) VALUES (
                :gps_id, :task_id, :submitted_by, :status, :media_type,
                :storage_url, :thumbnail_url, :file_size_bytes, :checksum,
                :mime_type, :latitude, :longitude, :captured_at, :uploaded_at,
                :created_at, :updated_at, :verifications, :metadata
            ) ON CONFLICT (gps_id) DO UPDATE SET
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
            'gps_id': gps_record.id,
            'task_id': gps_record.task_id,
            'submitted_by': gps_record.submitted_by,
            'status': gps_record.status.value,
            'media_type': gps_record.media_type.value,
            'storage_url': gps_record.storage_url,
            'thumbnail_url': gps_record.thumbnail_url,
            'file_size_bytes': gps_record.file_size_bytes,
            'checksum': gps_record.checksum,
            'mime_type': gps_record.mime_type,
            'latitude': gps_record.latitude,
            'longitude': gps_record.longitude,
            'captured_at': gps_record.captured_at,
            'uploaded_at': gps_record.uploaded_at,
            'created_at': gps_record.created_at,
            'updated_at': gps_record.updated_at,
            'verifications': str(gps_record.verifications),
            'metadata': gps_record.metadata,
        })