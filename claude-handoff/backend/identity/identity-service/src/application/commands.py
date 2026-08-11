"""Identity service commands (write-side)."""
from __future__ import annotations
from dataclasses import dataclass
from typing import Optional

from shared.utils.cqrs import Command


@dataclass
class RegisterUserCommand(Command):
    email:      str
    full_name:   str
    password:   str
    phone:      Optional[str] = None
    role:       str = "INDIVIDUAL"


@dataclass
class VerifyEmailCommand(Command):
    user_id: str
    token:   str


@dataclass
class UpdateUserProfileCommand(Command):
    user_id:    str
    bio:        Optional[str]   = None
    avatar_url: Optional[str]   = None
    country:    Optional[str]   = None
    city:       Optional[str]   = None
    languages:  Optional[list]  = None
    latitude:   Optional[float] = None
    longitude:  Optional[float] = None


@dataclass
class AddSkillToUserCommand(Command):
    user_id:    str
    skill_id:   str
    skill_name: str
    proficiency: str = "BEGINNER"


@dataclass
class SuspendUserCommand(Command):
    user_id:    str
    reason:     str
    admin_id:   str


@dataclass
class UpdatePMSScoreCommand(Command):
    user_id:    str
    new_score:  float
    dimensions: dict
