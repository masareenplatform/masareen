from dataclasses import dataclass
from typing import Any, Dict, Optional
from shared.utils.cqrs import Command

@dataclass
class SendNotificationCommand(Command):
    user_id: str
    channel: str
    title: str
    body: str
    data: Optional[Dict[str, Any]] = None

@dataclass
class MarkNotificationReadCommand(Command):
    user_id: str
    notification_id: str

@dataclass
class UpdateNotificationPreferencesCommand(Command):
    user_id: str
    push: bool
    email: bool
    sms: bool
    in_app: bool
