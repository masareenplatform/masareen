"""Unit tests for Opportunity aggregate."""
import pytest
from src.domain.opportunity import Opportunity, OpportunityType, OpportunityStatus
from shared.exceptions import ValidationException, ConflictException


def make_opp(**kwargs) -> Opportunity:
    defaults = dict(org_id="org-1", title="Community Health Researcher",
                    opp_type="JOB", created_by="admin-1")
    return Opportunity.create(**{**defaults, **kwargs})


class TestOpportunityCreation:
    def test_creates_in_draft_status(self):
        opp = make_opp()
        assert opp.status == OpportunityStatus.DRAFT
        assert opp.opp_type == OpportunityType.JOB

    def test_rejects_short_title(self):
        with pytest.raises(ValidationException):
            make_opp(title="NGO")

    def test_all_opportunity_types_valid(self):
        for t in ["JOB","FUNDING","SCHOLARSHIP","RESEARCH","CONSULTING","VOLUNTEER"]:
            opp = make_opp(opp_type=t)
            assert opp.opp_type.value == t


class TestOpportunityLifecycle:
    def test_publish_changes_status(self):
        opp = make_opp()
        opp.publish()
        assert opp.status == OpportunityStatus.PUBLISHED

    def test_cannot_publish_already_published(self):
        opp = make_opp()
        opp.publish()
        with pytest.raises(ConflictException):
            opp.publish()

    def test_close_sets_closed_status(self):
        opp = make_opp()
        opp.publish()
        opp.close()
        assert opp.status == OpportunityStatus.CLOSED


class TestProfileMatching:
    def test_matches_qualified_profile(self):
        opp = make_opp(min_pms_score=0.3,
                       required_skills=["community-outreach","data-collection"])
        matches, score = opp.matches_profile(
            pms_score=0.5,
            skills=["community-outreach","data-collection","reporting"],
            sdg_experience=[3, 10],
        )
        assert matches is True
        assert score > 0.5

    def test_rejects_below_pms_threshold(self):
        opp = make_opp(min_pms_score=0.6)
        matches, score = opp.matches_profile(pms_score=0.3, skills=[], sdg_experience=[])
        assert matches is False
        assert score == 0.0

    def test_no_requirements_matches_everyone(self):
        opp = make_opp(min_pms_score=0.0)
        matches, score = opp.matches_profile(pms_score=0.0, skills=[], sdg_experience=[])
        assert matches is True

    def test_partial_skill_overlap_reduces_score(self):
        opp = make_opp(min_pms_score=0.0,
                       required_skills=["skill-a","skill-b","skill-c","skill-d"])
        # Only 1 of 4 skills matched
        _, score_partial = opp.matches_profile(0.5, ["skill-a"], [])
        # All 4 skills matched
        _, score_full = opp.matches_profile(0.5, ["skill-a","skill-b","skill-c","skill-d"], [])
        assert score_full > score_partial
