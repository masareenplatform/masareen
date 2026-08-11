"""Unit tests for the Notification aggregate — no DB, no I/O."""
from src.domain.notification import Notification, NotificationStatus


class TestNotificationDomain:
    def test_create_defaults_to_pending(self):
        n = Notification.create("user-1", "VERIFICATION_APPROVED", "Hi", "Body")
        assert n.status == NotificationStatus.PENDING
        assert n.user_id == "user-1"
        assert n.payload == {}
        assert n.id

    def test_create_keeps_payload(self):
        n = Notification.create("u1", "OPPORTUNITY_MATCH", "T", "B", {"opp": "o1"})
        assert n.payload == {"opp": "o1"}

    def test_mark_sent_records_channel_and_time(self):
        n = Notification.create("u1", "GENERAL", "T", "B")
        n.mark_sent("EMAIL")
        assert n.status == NotificationStatus.SENT
        assert n.channel_used == "EMAIL"
        assert n.sent_at is not None

    def test_mark_read_sets_status_and_time(self):
        n = Notification.create("u1", "GENERAL", "T", "B")
        n.mark_read()
        assert n.status == NotificationStatus.READ
        assert n.read_at is not None
