"""Identity domain event contracts."""
from dataclasses import dataclass
from typing import Optional
from . import DomainEvent


@dataclass
class UserRegistered(DomainEvent):
    event_type: str = "UserRegistered"
    aggregate_type: str = "User"
    email: str = ""
    full_name: str = ""
    phone: Optional[str] = None
    role: str = "INDIVIDUAL"


@dataclass
class UserVerified(DomainEvent):
    event_type: str = "UserVerified"
    aggregate_type: str = "User"
    verification_method: str = ""


@dataclass
class PMSUpdated(DomainEvent):
    event_type: str = "PMSUpdated"
    aggregate_type: str = "User"
    previous_score: float = 0.0
    new_score: float = 0.0
    dimensions: dict = None

    def __post_init__(self):
        if self.dimensions is None:
            self.dimensions = {}


@dataclass
class EntityCreated(DomainEvent):
    event_type: str = "EntityCreated"
    aggregate_type: str = "Entity"
    entity_id: str = ""
    name: str = ""
    entity_type: str = ""


@dataclass
class EntityMemberAdded(DomainEvent):
    event_type: str = "EntityMemberAdded"
    aggregate_type: str = "Entity"
    entity_id: str = ""
    member_id: str = ""
    relation_type: str = ""
    role: Optional[str] = None


@dataclass
class EntityMemberRemoved(DomainEvent):
    event_type: str = "EntityMemberRemoved"
    aggregate_type: str = "Entity"
    entity_id: str = ""
    member_id: str = ""
