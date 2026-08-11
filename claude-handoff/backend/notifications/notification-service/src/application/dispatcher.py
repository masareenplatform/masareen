"""Notification dispatcher for MASAREN.

Pure delivery component: it selects channels and sends via real providers
(FCM / SMTP). Persistence is handled by the caller (via ``NotificationRepository``)
— the dispatcher does not fabricate or double-write records. A channel is only
attempted when a real recipient token/address is supplied.
"""
from typing import Any, Dict, Optional, Tuple

from ..infrastructure.providers import FCMProvider, EmailProvider, NotificationProvider
from shared.utils.logging import get_logger

log = get_logger(__name__)


class NotificationDispatcher:
    def __init__(self, fcm_key: str, repo=None, email_provider: Optional["EmailProvider"] = None):
        self.providers: Dict[str, NotificationProvider] = {
            "PUSH": FCMProvider(fcm_key),
            "EMAIL": email_provider or EmailProvider(),
        }
        self.repo = repo  # retained for callers that pass it; not used for writes here

    async def dispatch(self, user_id: str, trigger_type: str, payload: Dict[str, Any],
                       user_profile: Dict[str, Any], tokens: Dict[str, str],
                       title: Optional[str] = None, body: Optional[str] = None) -> bool:
        """Deliver to every channel with a real token. Returns True if any
        channel succeeded. Caller-supplied title/body take precedence; otherwise
        content is derived from the trigger + recipient persona."""
        if title is None or body is None:
            title, body = self._get_content(trigger_type, user_profile, payload)

        success = False
        for channel in self._get_channels(user_profile):
            provider = self.providers.get(channel)
            token = tokens.get(channel)
            if not provider or not token:
                continue
            try:
                if await provider.send(token, title, body, payload):
                    success = True
            except Exception as e:
                log.error(f"Failed to send {channel} notification to {user_id}: {e}")
        return success

    def _get_content(self, trigger: str, profile: Dict[str, Any],
                     payload: Dict[str, Any]) -> Tuple[str, str]:
        role = profile.get("role", "INDIVIDUAL")
        audience = profile.get("target_audience", "STUDENT")

        if trigger == "VERIFICATION_APPROVED":
            if role == "INDIVIDUAL":
                return "Impact Verified!", f"Your evidence for {payload.get('task_id')} has been approved."
            return "Evidence Approved", f"Verification for evidence {payload.get('id')} is complete."

        if trigger == "OPPORTUNITY_MATCH":
            if audience == "STUDENT":
                return "Career Boost!", f"A new opportunity matches your verified skills in {payload.get('sdg')}!"
            if audience == "PROFESSIONAL":
                return "Strategic Match", f"Your expertise is highly valued for: {payload.get('title')}."
            return "New Match", f"Check out this new opportunity: {payload.get('title')}."

        if trigger == "ADMIN_ACTION_REQUIRED":
            return "Action Required", "A high-risk verification needs your immediate approval."

        return "MASAREN Update", "You have a new notification."

    def _get_channels(self, profile: Dict[str, Any]) -> list:
        # Both channels are attempted; each is skipped unless a real token exists.
        return ["PUSH", "EMAIL"]
