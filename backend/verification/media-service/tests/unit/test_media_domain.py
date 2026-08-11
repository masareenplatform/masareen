import pytest
from src.domain.media_asset import MediaAsset, ProcessingStatus
from shared.exceptions import ValidationException


def test_create_media_asset(make_uuid):
    asset = MediaAsset.create_upload_slot(
        owner_id=make_uuid(),
        mime_type="image/jpeg",
        file_size_bytes=1024,
        evidence_id="ev-1",
        original_filename="photo.jpg",
    )
    assert asset.id
    assert asset.owner_id
    assert asset.mime_type == "image/jpeg"
    assert asset.file_size_bytes == 1024
    assert asset.evidence_id == "ev-1"
    assert asset.original_filename == "photo.jpg"
    assert asset.processing_status == ProcessingStatus.PENDING


def test_mark_processing():
    asset = MediaAsset(owner_id="owner-1", mime_type="image/jpeg")
    assert asset.processing_status == ProcessingStatus.PENDING
    asset.mark_uploaded(storage_key="uploads/abc.jpg", checksum="sha256:xyz")
    assert asset.processing_status == ProcessingStatus.PROCESSING
    assert asset.storage_key == "uploads/abc.jpg"
    assert asset.checksum_sha256 == "sha256:xyz"


def test_mark_completed():
    asset = MediaAsset(
        owner_id="owner-1",
        mime_type="image/jpeg",
        processing_status=ProcessingStatus.PROCESSING,
    )
    asset.mark_ready(
        cdn_url="https://cdn.masaren.io/asset.jpg",
        thumbnail_url="https://cdn.masaren.io/thumb.jpg",
        width=1920,
        height=1080,
        duration_seconds=30.5,
    )
    assert asset.processing_status == ProcessingStatus.READY
    assert asset.cdn_url == "https://cdn.masaren.io/asset.jpg"
    assert asset.thumbnail_url == "https://cdn.masaren.io/thumb.jpg"
    assert asset.width == 1920
    assert asset.height == 1080
    assert asset.duration_seconds == 30.5


def test_mark_failed():
    asset = MediaAsset(
        owner_id="owner-1",
        mime_type="image/jpeg",
        processing_status=ProcessingStatus.PROCESSING,
    )
    asset.mark_failed(reason="Processing timeout")
    assert asset.processing_status == ProcessingStatus.FAILED
    assert asset.metadata["failure_reason"] == "Processing timeout"


def test_validate_valid():
    asset = MediaAsset.create_upload_slot(
        owner_id="owner-1",
        mime_type="image/png",
        file_size_bytes=5_000_000,
    )
    assert asset.processing_status == ProcessingStatus.PENDING
    assert asset.mime_type == "image/png"


def test_validate_invalid_media_type():
    with pytest.raises(ValidationException, match="MIME type"):
        MediaAsset.create_upload_slot(
            owner_id="owner-1",
            mime_type="application/octet-stream",
            file_size_bytes=1024,
        )


def test_domain_events_emitted():
    asset = MediaAsset.create_upload_slot(
        owner_id="owner-1",
        mime_type="image/jpeg",
        file_size_bytes=1024,
    )
    events = asset.pull_domain_events()
    assert len(events) >= 1
    assert events[0].event_type == "MediaUploaded"
