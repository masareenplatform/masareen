"""Notification delivery providers.

Real integrations only:
- ``FCMProvider``   → Firebase Cloud Messaging HTTP API (Android/iOS/Web push).
- ``EmailProvider`` → SMTP (any provider: SendGrid/Mailgun/SES/self-hosted).

Neither provider fabricates a delivery receipt. If a provider is not configured
(missing key/host) it returns ``False`` and logs, it never claims a fake success.
"""
import asyncio
import os
import smtplib
from email.mime.text import MIMEText
from abc import ABC, abstractmethod
from typing import Any, Dict, Optional

import httpx

from shared.utils.logging import get_logger

log = get_logger(__name__)

class NotificationProvider(ABC):
    """Abstract base class for notification providers."""
    @abstractmethod
    async def send(self, token: str, title: str, body: str, data: Optional[Dict] = None) -> bool:
        pass

class FCMProvider(NotificationProvider):
    """Firebase Cloud Messaging push delivery (Android / iOS / Web).

    Prefers the **FCM HTTP v1 API** (OAuth2 service-account auth), which is the
    only supported API since Google decommissioned the legacy
    ``/fcm/send`` server-key endpoint in June 2024. Configuration (env):

    - ``FCM_SERVICE_ACCOUNT_FILE`` (or ``GOOGLE_APPLICATION_CREDENTIALS``), path
      to the Firebase service-account JSON, and
    - ``FCM_PROJECT_ID``, the Firebase project id.

    If a v1 service account is not configured but a legacy server key *is*
    provided (``api_key``), the legacy endpoint is attempted as a fallback. When
    nothing is configured the provider returns ``False`` and logs, it never
    fabricates a delivery receipt.
    """

    _V1_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"

    def __init__(self, api_key: str = ""):
        self.api_key = api_key or ""
        self.legacy_url = "https://fcm.googleapis.com/fcm/send"
        self.sa_file = (
            os.getenv("FCM_SERVICE_ACCOUNT_FILE")
            or os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
            or ""
        )
        self.project_id = os.getenv("FCM_PROJECT_ID", "")
        self._credentials = None  # lazily minted google.oauth2 credentials

    # ── FCM HTTP v1 ────────────────────────────────────────────────────────────
    def _v1_configured(self) -> bool:
        return bool(self.sa_file and self.project_id)

    def _get_v1_token(self) -> Optional[str]:
        """Mint (and refresh) an OAuth2 bearer token from the service account.

        Lazily imports ``google.auth`` so the dependency is optional; returns
        ``None`` (never a fake token) if unavailable or misconfigured.
        """
        try:  # pragma: no cover - requires google-auth + real service account
            from google.oauth2 import service_account  # type: ignore
            from google.auth.transport.requests import Request as GoogleRequest  # type: ignore

            if self._credentials is None:
                self._credentials = service_account.Credentials.from_service_account_file(
                    self.sa_file, scopes=[self._V1_SCOPE]
                )
            if not self._credentials.valid:
                self._credentials.refresh(GoogleRequest())
            return self._credentials.token
        except Exception as e:  # pragma: no cover
            log.error(f"FCM v1 token acquisition failed: {e}")
            return None

    async def _send_v1(self, token: str, title: str, body: str,
                       data: Optional[Dict]) -> bool:  # pragma: no cover - live API
        access_token = await asyncio.to_thread(self._get_v1_token)
        if not access_token:
            return False
        url = f"https://fcm.googleapis.com/v1/projects/{self.project_id}/messages:send"
        # FCM v1 requires all `data` values to be strings.
        str_data = {str(k): str(v) for k, v in (data or {}).items()}
        message = {
            "message": {
                "token": token,
                "notification": {"title": title, "body": body},
                "data": str_data,
                "android": {"priority": "high"},
            }
        }
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json",
        }
        async with httpx.AsyncClient(timeout=15) as client:
            try:
                resp = await client.post(url, headers=headers, json=message)
                resp.raise_for_status()
                log.info(f"FCM v1 push sent to token: {token[:8]}...")
                return True
            except Exception as e:
                log.error(f"FCM v1 push failed: {e}")
                return False

    # ── Legacy fallback (deprecated by Google) ──────────────────────────────────
    async def _send_legacy(self, token: str, title: str, body: str,
                           data: Optional[Dict]) -> bool:  # pragma: no cover - live API
        payload = {
            "to": token,
            "notification": {"title": title, "body": body, "sound": "default", "badge": "1"},
            "data": data or {},
            "priority": "high",
        }
        headers = {"Authorization": f"key={self.api_key}", "Content-Type": "application/json"}
        async with httpx.AsyncClient(timeout=15) as client:
            try:
                resp = await client.post(self.legacy_url, headers=headers, json=payload)
                resp.raise_for_status()
                log.info(f"FCM (legacy) push sent to token: {token[:8]}...")
                return True
            except Exception as e:
                log.error(f"FCM (legacy) push failed: {e}")
                return False

    async def send(self, token: str, title: str, body: str, data: Optional[Dict] = None) -> bool:
        if not token:
            log.warning("fcm_no_recipient_token")
            return False
        if self._v1_configured():
            return await self._send_v1(token, title, body, data)
        if self.api_key:
            return await self._send_legacy(token, title, body, data)
        log.warning("fcm_not_configured")  # honest: no v1 service account, no legacy key
        return False

class EmailProvider(NotificationProvider):
    """SMTP email delivery. ``token`` is the recipient email address.

    Works with any SMTP provider (SendGrid, Mailgun, Amazon SES, self-hosted).
    Returns ``False`` (never a fake success) when SMTP is not configured or the
    send fails.
    """
    def __init__(self, host: str = "", port: int = 587, username: str = "",
                 password: str = "", sender: str = "no-reply@masaren.io",
                 use_tls: bool = True):
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.sender = sender
        self.use_tls = use_tls

    def _send_sync(self, to_addr: str, title: str, body: str) -> bool:
        msg = MIMEText(body, "plain", "utf-8")
        msg["Subject"] = title
        msg["From"] = self.sender
        msg["To"] = to_addr
        with smtplib.SMTP(self.host, self.port, timeout=15) as server:
            if self.use_tls:
                server.starttls()
            if self.username:
                server.login(self.username, self.password)
            server.sendmail(self.sender, [to_addr], msg.as_string())
        return True

    async def send(self, token: str, title: str, body: str, data: Optional[Dict] = None) -> bool:
        if not self.host or not token:
            log.warning("email_not_configured_or_no_recipient", configured=bool(self.host))
            return False
        try:
            # smtplib is blocking; run it off the event loop.
            return await asyncio.to_thread(self._send_sync, token, title, body)
        except Exception as e:
            log.error(f"SMTP email failed: {e}")
            return False
