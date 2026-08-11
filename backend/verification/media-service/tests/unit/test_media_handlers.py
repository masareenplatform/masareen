from unittest.mock import AsyncMock, MagicMock
import pytest

from src.domain.media_asset import MediaAsset
from src.application.commands import (
    CreateUploadSlotCommand, UploadMediaCommand,
    ProcessMediaCommand, DeleteMediaCommand,
)
from src.application.handlers import (
    CreateUploadSlotHandler, UploadMediaHandler,
    ProcessMediaHandler, DeleteMediaHandler,
)
from shared.exceptions import NotFoundException


class TestCreateUploadSlotHandler:
    @pytest.mark.asyncio
    async def test_create_upload_slot_handler(self):
        cmd = CreateUploadSlotCommand(
            owner_id="user-1",
            mime_type="image/jpeg",
            file_size_bytes=2048,
            evidence_id="ev-1",
            original_filename="photo.jpg",
        )
        mock_repo = MagicMock()
        mock_repo.save = AsyncMock(side_effect=lambda asset: asset)
        mock_outbox = MagicMock()
        mock_outbox.write = AsyncMock()
        mock_session = AsyncMock()

        handler = CreateUploadSlotHandler(mock_repo, mock_outbox, mock_session)
        result = await handler.handle(cmd)

        assert "asset_id" in result
        assert isinstance(result["asset_id"], str)
        assert result["status"] == "PENDING"
        mock_repo.save.assert_awaited_once()
        mock_outbox.write.assert_awaited_once()


class TestUploadMediaHandler:
    @pytest.mark.asyncio
    async def test_upload_media_handler(self):
        asset = MediaAsset.create_upload_slot("user-1", "image/jpeg", 2048)
        asset.pull_domain_events()

        mock_repo = MagicMock()
        mock_repo.get_by_id = AsyncMock(return_value=asset)
        mock_repo.save = AsyncMock(side_effect=lambda a: a)
        mock_outbox = MagicMock()
        mock_outbox.write = AsyncMock()
        mock_session = AsyncMock()

        handler = UploadMediaHandler(mock_repo, mock_outbox, mock_session)
        cmd = UploadMediaCommand(asset_id=asset.id)
        result = await handler.handle(cmd)

        assert result["asset_id"] == asset.id
        assert result["status"] == "PROCESSING"
        mock_repo.get_by_id.assert_awaited_once()
        mock_repo.save.assert_awaited_once()
        mock_outbox.write.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_upload_media_not_found(self):
        mock_repo = MagicMock()
        mock_repo.get_by_id = AsyncMock(return_value=None)
        mock_outbox = MagicMock()
        mock_outbox.write = AsyncMock()
        mock_session = AsyncMock()

        handler = UploadMediaHandler(mock_repo, mock_outbox, mock_session)
        cmd = UploadMediaCommand(asset_id="nonexistent")
        with pytest.raises(NotFoundException):
            await handler.handle(cmd)


class TestProcessMediaHandler:
    @pytest.mark.asyncio
    async def test_process_media_handler(self):
        asset = MediaAsset.create_upload_slot("user-1", "image/jpeg", 2048)
        asset.pull_domain_events()
        asset.mark_uploaded("key-1", "checksum-1")

        mock_repo = MagicMock()
        mock_repo.get_by_id = AsyncMock(return_value=asset)
        mock_repo.save = AsyncMock(side_effect=lambda a: a)
        mock_outbox = MagicMock()
        mock_outbox.write = AsyncMock()
        mock_session = AsyncMock()

        handler = ProcessMediaHandler(mock_repo, mock_outbox, mock_session)
        cmd = ProcessMediaCommand(
            asset_id=asset.id,
            cdn_url="http://cdn.example.com/img.jpg",
            checksum="checksum-1",
            width=800,
            height=600,
        )
        result = await handler.handle(cmd)

        assert result["asset_id"] == asset.id
        assert result["status"] == "READY"
        mock_repo.get_by_id.assert_awaited_once()
        mock_repo.save.assert_awaited_once()
        mock_outbox.write.assert_not_called()

    @pytest.mark.asyncio
    async def test_process_media_not_found(self):
        mock_repo = MagicMock()
        mock_repo.get_by_id = AsyncMock(return_value=None)
        mock_outbox = MagicMock()
        mock_outbox.write = AsyncMock()
        mock_session = AsyncMock()

        handler = ProcessMediaHandler(mock_repo, mock_outbox, mock_session)
        cmd = ProcessMediaCommand(asset_id="nonexistent", cdn_url="", checksum="")
        with pytest.raises(NotFoundException):
            await handler.handle(cmd)


class TestDeleteMediaHandler:
    @pytest.mark.asyncio
    async def test_delete_media_handler(self):
        asset = MediaAsset.create_upload_slot("user-1", "image/jpeg", 2048)
        asset.pull_domain_events()

        mock_repo = MagicMock()
        mock_repo.get_by_id = AsyncMock(return_value=asset)
        mock_repo.delete = AsyncMock()
        mock_outbox = MagicMock()
        mock_outbox.write = AsyncMock()
        mock_session = AsyncMock()

        handler = DeleteMediaHandler(mock_repo, mock_outbox, mock_session)
        cmd = DeleteMediaCommand(asset_id=asset.id)
        result = await handler.handle(cmd)

        assert result["asset_id"] == asset.id
        assert result["status"] == "DELETED"
        mock_repo.get_by_id.assert_awaited_once()
        mock_repo.delete.assert_awaited_once()
        mock_outbox.write.assert_not_called()

    @pytest.mark.asyncio
    async def test_delete_media_not_found(self):
        mock_repo = MagicMock()
        mock_repo.get_by_id = AsyncMock(return_value=None)
        mock_outbox = MagicMock()
        mock_outbox.write = AsyncMock()
        mock_session = AsyncMock()

        handler = DeleteMediaHandler(mock_repo, mock_outbox, mock_session)
        cmd = DeleteMediaCommand(asset_id="nonexistent")
        with pytest.raises(NotFoundException):
            await handler.handle(cmd)
