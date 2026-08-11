"""Unit tests for the User aggregate — no DB, no Kafka, no I/O."""
import pytest
from src.domain.user import User, UserRole, UserStatus, UserProfile
from shared.exceptions import ValidationException, ConflictException


class TestUserRegistration:
    def test_register_creates_user_with_correct_defaults(self):
        user = User.register(
            email="sherif@masaren.io",
            full_name="Sherif Ahmed",
            hashed_password="hashed_pw_123",
        )
        assert user.email == "sherif@masaren.io"
        assert user.role == UserRole.INDIVIDUAL
        assert user.status == UserStatus.PENDING_VERIFICATION
        assert user.email_verified is False
        assert user.pms_score == 0.0

    def test_register_emits_user_registered_event(self):
        user = User.register(
            email="test@example.com",
            full_name="Test User",
            hashed_password="pw",
        )
        events = user.pull_domain_events()
        assert len(events) == 1
        assert events[0].event_type == "UserRegistered"
        assert events[0].email == "test@example.com"

    def test_register_normalises_email_to_lowercase(self):
        user = User.register(
            email="Sherif@MASAREEN.IO",
            full_name="Sherif",
            hashed_password="pw",
        )
        assert user.email == "sherif@masaren.io"

    def test_register_rejects_invalid_email(self):
        with pytest.raises(ValidationException):
            User.register(email="not-an-email", full_name="Test", hashed_password="pw")

    def test_register_rejects_short_name(self):
        with pytest.raises(ValidationException):
            User.register(email="a@b.com", full_name="X", hashed_password="pw")

    def test_register_rejects_empty_password(self):
        with pytest.raises(ValidationException):
            User.register(email="a@b.com", full_name="Valid Name", hashed_password="")


class TestUserEmailVerification:
    def test_verify_email_sets_email_verified_and_activates(self):
        user = User.register("a@b.com", "Test User", "pw")
        user.pull_domain_events()  # Clear register event
        user.verify_email()
        assert user.email_verified is True
        assert user.status == UserStatus.ACTIVE

    def test_verify_email_emits_user_verified_event(self):
        user = User.register("a@b.com", "Test User", "pw")
        user.pull_domain_events()
        user.verify_email()
        events = user.pull_domain_events()
        assert any(e.event_type == "UserVerified" for e in events)

    def test_verify_email_idempotent_on_second_call(self):
        user = User.register("a@b.com", "Test User", "pw")
        user.verify_email()
        user.pull_domain_events()
        user.verify_email()  # Second call — should not emit again
        events = user.pull_domain_events()
        assert not any(e.event_type == "UserVerified" for e in events)


class TestUserProfile:
    def test_update_profile_stores_values(self):
        user = User.register("a@b.com", "Test User", "pw")
        user.update_profile(UserProfile(bio="Field researcher", country="EG", city="Cairo"))
        assert user.profile.bio == "Field researcher"
        assert user.profile.country == "EG"

    def test_add_skill_appends_to_list(self):
        from src.domain.user import UserSkill
        user = User.register("a@b.com", "Test User", "pw")
        user.add_skill(UserSkill(skill_id="s1", skill_name="Community Outreach"))
        assert len(user.skills) == 1
        assert user.skills[0].skill_name == "Community Outreach"

    def test_add_duplicate_skill_raises_conflict(self):
        from src.domain.user import UserSkill
        user = User.register("a@b.com", "Test User", "pw")
        skill = UserSkill(skill_id="s1", skill_name="Community Outreach")
        user.add_skill(skill)
        with pytest.raises(ConflictException):
            user.add_skill(UserSkill(skill_id="s1", skill_name="Duplicate"))


class TestPMSScore:
    def test_update_pms_score_emits_event(self):
        user = User.register("a@b.com", "Test", "pw")
        user.pull_domain_events()
        user.update_pms_score(0.72, {"reliability": 0.80, "leadership": 0.65})
        events = user.pull_domain_events()
        pms_events = [e for e in events if e.event_type == "PMSUpdated"]
        assert len(pms_events) == 1
        assert pms_events[0].new_score == 0.72
        assert pms_events[0].previous_score == 0.0


class TestImpactPassport:
    def test_tier_computation_bronze(self):
        from src.domain.value_objects import ImpactPassport
        assert ImpactPassport.compute_tier(0.0)  == "BRONZE"
        assert ImpactPassport.compute_tier(0.39) == "BRONZE"

    def test_tier_computation_silver(self):
        from src.domain.value_objects import ImpactPassport
        assert ImpactPassport.compute_tier(0.40) == "SILVER"

    def test_tier_computation_gold(self):
        from src.domain.value_objects import ImpactPassport
        assert ImpactPassport.compute_tier(0.65) == "GOLD"

    def test_tier_computation_platinum(self):
        from src.domain.value_objects import ImpactPassport
        assert ImpactPassport.compute_tier(0.85) == "PLATINUM"
        assert ImpactPassport.compute_tier(1.0)  == "PLATINUM"

    def test_passport_id_format(self):
        from src.domain.value_objects import ImpactPassport
        p = ImpactPassport(user_id="abcd1234-efgh-5678-ijkl-mnop90123456", tier="GOLD", level=2)
        assert p.passport_id.startswith("MP-")
        assert "GOLD" in p.passport_id
        assert "L2" in p.passport_id
