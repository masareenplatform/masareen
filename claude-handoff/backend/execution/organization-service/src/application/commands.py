from dataclasses import dataclass
from typing import Optional, Dict, Any
from shared.utils.cqrs import Command

@dataclass
class CreateOrganizationCommand(Command):
    name: str; org_type: str; country: str; created_by: str
    description: Optional[str] = None; website: Optional[str] = None

@dataclass
class VerifyOrganizationCommand(Command):
    org_id: str; admin_id: str

@dataclass
class AddMemberCommand(Command):
    org_id: str; user_id: str; added_by: str

@dataclass
class RemoveMemberCommand(Command):
    org_id: str; user_id: str; removed_by: str

@dataclass
class SuspendOrganizationCommand(Command):
    org_id: str; admin_id: str; reason: str

@dataclass
class UpdateOrganizationProfileCommand(Command):
    org_id: str
    profile_data: Dict[str, Any]

@dataclass
class AddTimelineEventCommand(Command):
    entity_id: str
    event_type: str
    title: str
    description: Optional[str] = None
    date: Optional[str] = None
    media_url: Optional[str] = None
    metric_value: Optional[float] = None
    metadata: Optional[Dict[str, Any]] = None
