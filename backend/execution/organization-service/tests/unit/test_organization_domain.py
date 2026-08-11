"""Unit tests for the Organization aggregate — no DB, no I/O."""
import pytest

from src.domain.organization import Organization, OrgType, OrgStatus
from src.domain.affiliation import AffiliationRole
from shared.exceptions import ValidationException, ConflictException


def make_org(**kw) -> Organization:
    defaults = dict(name="Green Future NGO", org_type=OrgType.NGO,
                    country="EG", created_by="user-1")
    return Organization.create(**{**defaults, **kw})


class TestOrganizationCreation:
    def test_creates_with_pending_status(self):
        org = make_org()
        assert org.status == OrgStatus.PENDING
        assert org.verified is False

    def test_generates_slug(self):
        org = make_org(name="Green Future NGO")
        assert org.slug == "green-future-ngo"

    def test_sets_country_on_address(self):
        org = make_org(country="EG")
        assert org.address is not None
        assert org.address.country == "EG"

    def test_emits_organization_created_event(self):
        org = make_org()
        events = org.pull_domain_events()
        assert any(e.event_type == "OrganizationCreated" for e in events)

    def test_rejects_empty_name(self):
        with pytest.raises(ValidationException):
            make_org(name="")


class TestOrganizationLifecycle:
    def test_verify_sets_verified(self):
        org = make_org()
        org.verify(admin_id="admin-1")
        assert org.status == OrgStatus.VERIFIED
        assert org.verified is True

    def test_add_member_appends_affiliation(self):
        org = make_org()
        org.add_member("user-2", AffiliationRole.CONTRIBUTOR)
        assert len(org.affiliations) == 1
        assert org.affiliations[0].user_id == "user-2"
        assert org.affiliations[0].role == AffiliationRole.CONTRIBUTOR

    def test_add_duplicate_member_raises_conflict(self):
        org = make_org()
        org.add_member("user-2")
        with pytest.raises(ConflictException):
            org.add_member("user-2")

    def test_remove_affiliation(self):
        org = make_org()
        org.add_member("user-2")
        org.remove_affiliation("user-2")
        assert org.affiliations == []

    def test_update_profile_stores_data(self):
        org = make_org()
        org.update_profile({"mission": "Reforestation", "founded": 2018})
        assert org.profile.data["mission"] == "Reforestation"
