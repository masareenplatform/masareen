"""Unit tests for the Task aggregate FSM — no DB, no I/O."""
import pytest
from datetime import datetime, timezone, timedelta
from src.domain.task import Task, TaskStatus, TaskPriority, TaskGeofence
from shared.exceptions import ValidationException, ConflictException


def make_task(**kwargs) -> Task:
    defaults = dict(program_id="prog-1", title="Build Community Centre",
                    created_by="user-1", priority="HIGH")
    return Task.create(**{**defaults, **kwargs})


class TestTaskCreation:
    def test_creates_with_pending_status(self):
        t = make_task()
        assert t.status == TaskStatus.PENDING
        assert t.priority == TaskPriority.HIGH
        assert t.evidence_required is True

    def test_rejects_short_title(self):
        with pytest.raises(ValidationException):
            make_task(title="AB")

    def test_rejects_missing_program_id(self):
        with pytest.raises(ValidationException):
            make_task(program_id="")

    def test_stores_geofence(self):
        t = make_task(geofence_lat=30.0626, geofence_lon=31.2497)
        t2 = Task.create("p","Build Water Well","u",
            geofence=TaskGeofence(30.0626, 31.2497, 200))
        assert t2.geofence.radius_meters == 200


class TestTaskFSM:
    def test_full_happy_path(self):
        t = make_task()
        t.assign("user-2", "supervisor-1")
        assert t.status == TaskStatus.ASSIGNED
        t.start("user-2")
        assert t.status == TaskStatus.IN_PROGRESS
        t.submit("user-2", ["ev-1","ev-2"], actual_hours=3.5)
        assert t.status == TaskStatus.SUBMITTED
        t.verify("supervisor-1", "Confirmed on site")
        assert t.status == TaskStatus.VERIFIED
        t.complete("supervisor-1")
        assert t.status == TaskStatus.COMPLETED

    def test_assign_emits_task_assigned_event(self):
        t = make_task()
        t.assign("user-2", "supervisor-1")
        events = t.pull_domain_events()
        assert any(e.event_type == "TaskAssigned" for e in events)

    def test_complete_emits_task_completed_event(self):
        t = make_task(evidence_required=False)
        t.assign("u2","s1"); t.start("u2"); t.submit("u2",[]); t.verify("s1"); t.complete("s1")
        events = t.pull_domain_events()
        assert any(e.event_type == "TaskCompleted" for e in events)

    def test_invalid_transition_raises_conflict(self):
        t = make_task()
        with pytest.raises(ConflictException):
            t.start("user-2")  # Cannot start from PENDING

    def test_cannot_start_if_not_assignee(self):
        t = make_task()
        t.assign("user-2", "supervisor-1")
        with pytest.raises(ValidationException):
            t.start("wrong-user")

    def test_submit_requires_evidence_when_required(self):
        t = make_task(evidence_required=True)
        t.assign("u2","s1"); t.start("u2")
        with pytest.raises(ValidationException):
            t.submit("u2", [])  # No evidence provided

    def test_cancel_from_any_active_state(self):
        for setup in [
            lambda t: None,                               # PENDING
            lambda t: t.assign("u2","s1"),                # ASSIGNED
            lambda t: [t.assign("u2","s1"), t.start("u2")], # IN_PROGRESS
        ]:
            t = make_task()
            setup(t)
            t.cancel("admin", "Test cancellation")
            assert t.status == TaskStatus.CANCELLED

    def test_cannot_cancel_completed_task(self):
        t = make_task(evidence_required=False)
        t.assign("u2","s1"); t.start("u2"); t.submit("u2",[]); t.verify("s1"); t.complete("s1")
        with pytest.raises(ConflictException):
            t.cancel("admin", "Too late")

    def test_status_history_is_recorded(self):
        t = make_task()
        t.assign("user-2", "supervisor-1")
        t.start("user-2")
        assert len(t.status_history) == 2
        assert t.status_history[0].from_status == "PENDING"
        assert t.status_history[0].to_status   == "ASSIGNED"
        assert t.status_history[1].from_status == "ASSIGNED"
        assert t.status_history[1].to_status   == "IN_PROGRESS"

    def test_evidence_ids_appended_on_submit(self):
        t = make_task()
        t.assign("u2","s1"); t.start("u2")
        t.submit("u2", ["ev-1","ev-2"])
        assert "ev-1" in t.evidence_ids and "ev-2" in t.evidence_ids


class TestTaskOverdue:
    def test_overdue_detection(self):
        past = datetime.now(timezone.utc) - timedelta(days=1)
        t = make_task(due_date=past)
        t.assign("u2","s1")
        assert t.is_overdue() is True

    def test_completed_task_not_overdue(self):
        past = datetime.now(timezone.utc) - timedelta(days=1)
        t = make_task(due_date=past, evidence_required=False)
        t.assign("u2","s1"); t.start("u2"); t.submit("u2",[]); t.verify("s1"); t.complete("s1")
        assert t.is_overdue() is False

