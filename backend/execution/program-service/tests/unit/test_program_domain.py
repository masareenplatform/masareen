"""Unit tests for the Program aggregate, no DB, no I/O."""
import pytest
from datetime import date, timedelta

from src.domain.program import Program, ProgramStatus
from shared.exceptions import ValidationException, ConflictException


def make_program(**kw) -> Program:
    defaults = dict(org_id="org-1", title="Clean Nile Initiative", created_by="user-1")
    return Program.create(**{**defaults, **kw})


class TestProgramCreation:
    def test_creates_with_draft_status(self):
        p = make_program()
        assert p.status == ProgramStatus.DRAFT

    def test_rejects_short_title(self):
        with pytest.raises(ValidationException):
            make_program(title="AB")

    def test_rejects_end_before_start(self):
        with pytest.raises(ValidationException):
            make_program(start_date=date(2026, 5, 1), end_date=date(2026, 4, 1))

    def test_emits_program_created_event(self):
        p = make_program(sdg_goals=[6, 13])
        events = p.pull_domain_events()
        assert any(e.event_type == "ProgramCreated" for e in events)


class TestProgramLifecycle:
    def test_publish_from_draft(self):
        p = make_program()
        p.publish()
        assert p.status == ProgramStatus.PUBLISHED

    def test_cannot_publish_twice(self):
        p = make_program()
        p.publish()
        with pytest.raises(ConflictException):
            p.publish()

    def test_activate_after_publish(self):
        p = make_program()
        p.publish()
        p.activate()
        assert p.status == ProgramStatus.ACTIVE

    def test_cannot_activate_from_draft(self):
        p = make_program()
        with pytest.raises(ConflictException):
            p.activate()

    def test_enroll_increments_count(self):
        p = make_program(max_participants=2)
        p.enroll_participant()
        assert p.enrolled_count == 1

    def test_enroll_beyond_capacity_raises(self):
        p = make_program(max_participants=1)
        p.enroll_participant()
        with pytest.raises(ConflictException):
            p.enroll_participant()

    def test_add_milestone(self):
        p = make_program()
        m = p.add_milestone("Kickoff", due_date=date.today() + timedelta(days=30))
        assert m in p.milestones
        assert m.title == "Kickoff"
