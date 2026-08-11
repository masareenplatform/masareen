import pytest
from src.domain.review_queue import ReviewQueueItem, ReviewStatus
from datetime import datetime, timezone

def test_review_item_creation():
    item = ReviewQueueItem(
        entity_id="ev-123",
        entity_type="EVIDENCE",
        confidence_score=0.65,
        status=ReviewStatus.PENDING
    )
    assert item.entity_id == "ev-123"
    assert item.status == ReviewStatus.PENDING

def test_review_resolution():
    item = ReviewQueueItem(
        entity_id="ev-123",
        entity_type="EVIDENCE",
        confidence_score=0.65,
        status=ReviewStatus.PENDING
    )
    item.resolve(
        admin_id="admin-1",
        verdict=ReviewStatus.APPROVED,
        comments="Evidence verified by human auditor"
    )
    assert item.status == ReviewStatus.APPROVED
    assert item.assigned_admin_id == "admin-1"
    assert item.admin_comments == "Evidence verified by human auditor"
    assert item.resolved_at is not None
