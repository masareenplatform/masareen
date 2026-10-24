"""Organization aggregate root, Execution domain."""
from __future__ import annotations
from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import List, Optional, Dict, Any
from uuid import uuid4

import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "../../../../shared"))

from shared.base_entity import AggregateRoot
from shared.events.execution_events import OrganizationCreated
from shared.exceptions import ValidationException, ConflictException
from .affiliation import Affiliation, AffiliationRole


class OrgType(str, Enum):
    NGO           = "NGO"
    CSR           = "CSR"
    GOVERNMENT    = "GOVERNMENT"
    UNIVERSITY    = "UNIVERSITY"
    FOUNDATION    = "FOUNDATION"
    RESEARCH      = "RESEARCH"
    INTERNATIONAL = "INTERNATIONAL"
    CORPORATE     = "CORPORATE"
    MEDIA         = "MEDIA"
    SPORTS        = "SPORTS"
    EDUCATION     = "EDUCATION"

class OrgStatus(str, Enum):
    PENDING    = "PENDING"
    ACTIVE     = "ACTIVE"
    SUSPENDED  = "SUSPENDED"
    VERIFIED   = "VERIFIED"

@dataclass
class OrganizationAddress:
    country: str
    city:    Optional[str] = None
    street:  Optional[str] = None
    postal:  Optional[str] = None

@dataclass
class OrganizationProfile:
    """Base class for specialized institutional profiles."""
    data: Dict[str, Any] = field(default_factory=dict)

@dataclass
class Organization(AggregateRoot):
    name:        str             = ""
    slug:        str             = ""
    subdomain:   Optional[str]   = None
    org_type:    OrgType         = OrgType.NGO
    status:      OrgStatus       = OrgStatus.PENDING
    description: Optional[str]   = None
    website:     Optional[str]   = None
    logo_url:    Optional[str]   = None
    address:     Optional[OrganizationAddress] = None
    oii_score:   float           = 0.0
    verified:    bool            = False
    subscription_tier: str       = "FREE"
    affiliations: List[Affiliation] = field(default_factory=list)
    admin_ids:   List[str]       = field(default_factory=list)
    profile:     Optional[OrganizationProfile] = None

    @classmethod
    def create(cls, name: str, org_type: OrgType, country: str, created_by: str, description: Optional[str] = None, website: Optional[str] = None) -> "Organization":
        if not name:
            raise ValidationException("Organization name is required.")
        
        # Simple slug generation
        slug = name.lower().replace(" ", "-")
        now = datetime.now(timezone.utc)
        
        org = cls(
            id=str(uuid4()),
            name=name,
            slug=slug,
            org_type=org_type,
            status=OrgStatus.PENDING,
            description=description,
            website=website,
            address=OrganizationAddress(country=country),
            created_at=now,
            updated_at=now
        )
        org.add_domain_event(OrganizationCreated(
            name=name,
            org_type=org_type.value,
            country=country
        ))
        return org

    def verify(self, admin_id: str) -> None:
        self.status = OrgStatus.VERIFIED
        self.verified = True
        self.updated_at = datetime.now(timezone.utc)
        # Could add OrganizationVerified event here if needed

    def add_member(self, user_id: str, role: AffiliationRole = AffiliationRole.MEMBER) -> None:
        if any(a.user_id == user_id for a in self.affiliations):
            raise ConflictException(f"User {user_id} already affiliated.")
        
        affiliation = Affiliation(user_id=user_id, org_id=self.id, role=role)
        self.affiliations.append(affiliation)
        self.updated_at = datetime.now(timezone.utc)

    def remove_affiliation(self, user_id: str) -> None:
        self.affiliations = [a for a in self.affiliations if a.user_id != user_id]
        self.updated_at = datetime.now(timezone.utc)

    def update_profile(self, profile_data: Dict[str, Any]) -> None:
        self.profile = OrganizationProfile(data=profile_data)
        self.updated_at = datetime.now(timezone.utc)

