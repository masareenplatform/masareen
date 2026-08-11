import pytest
from src.domain.platform_content import PlatformPost, ContentType
from decimal import Decimal

def test_platform_post_creation():
    post = PlatformPost.create(
        title="How to use MASAREEN",
        body="Follow these steps...",
        content_type="EDUCATIONAL",
        target=["STUDENTS"]
    )
    assert post.title == "How to use MASAREEN"
    assert post.content_type == ContentType.EDUCATIONAL
    assert "STUDENTS" in post.target_audience

def test_ad_budget_depletion():
    post = PlatformPost.create(
        title="Premium Verification",
        body="Get verified faster!",
        content_type="AD",
        budget=1.0 # $1.00 budget
    )
    
    # Initial state
    assert post.is_active is True
    
    # Simulate impressions (0.01 per impression)
    for _ in range(100):
        post.record_impression()
        
    assert post.current_spend == Decimal("1.00")
    assert post.is_active is False # Budget exhausted

def test_ad_click_cost():
    post = PlatformPost.create(
        title="Ad",
        body="Body",
        content_type="AD",
        budget=10.0
    )
    post.record_click()
    assert post.current_spend == Decimal("0.10") # Cost per click
