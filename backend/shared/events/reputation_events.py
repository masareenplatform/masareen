"""Reputation domain event contracts."""
from dataclasses import dataclass
from . import DomainEvent


@dataclass
class CertificateIssued(DomainEvent):
    event_type: str = "CertificateIssued"
    aggregate_type: str = "Certificate"
    user_id: str = ""
    program_id: str = ""
    issuer_org_id: str = ""
    certificate_type: str = ""
    blockchain_hash: str = ""


@dataclass
class OIIUpdated(DomainEvent):
    event_type: str = "OIIUpdated"
    aggregate_type: str = "Organization"
    previous_index: float = 0.0
    new_index: float = 0.0
    dimensions: dict = None

    def __post_init__(self):
        if self.dimensions is None:
            self.dimensions = {}
