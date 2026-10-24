"""Impact Report aggregate, SDG-aligned auto-generated reports."""
from __future__ import annotations
from dataclasses import dataclass, field
from datetime import date, datetime, timezone
from enum import Enum
from typing import Dict, List, Optional
from uuid import uuid4
from shared.base_entity import AggregateRoot
from shared.exceptions import ValidationException


class ReportType(str, Enum):
    INDIVIDUAL_IMPACT  = "INDIVIDUAL_IMPACT"
    PROGRAM_SUMMARY    = "PROGRAM_SUMMARY"
    ORGANIZATION_ANNUAL= "ORGANIZATION_ANNUAL"
    SDG_PROGRESS       = "SDG_PROGRESS"
    DONOR_REPORT       = "DONOR_REPORT"
    ESG_COMPLIANCE     = "ESG_COMPLIANCE"


class ReportStatus(str, Enum):
    QUEUED      = "QUEUED"
    GENERATING  = "GENERATING"
    READY       = "READY"
    FAILED      = "FAILED"


@dataclass
class SDGIndicator:
    goal: int; indicator_code: str; value: float; unit: str; description: str


@dataclass
class ReportSection:
    title: str; content: str; charts: List[dict] = field(default_factory=list)


@dataclass
class ImpactReport(AggregateRoot):
    report_type:    ReportType           = ReportType.PROGRAM_SUMMARY
    status:         ReportStatus         = ReportStatus.QUEUED
    entity_id:      str                  = ""    # program_id or org_id or user_id
    entity_type:    str                  = ""    # PROGRAM | ORGANIZATION | USER
    period_start:   Optional[date]       = None
    period_end:     Optional[date]       = None
    title:          str                  = ""
    executive_summary: Optional[str]     = None
    sections:       List[ReportSection]  = field(default_factory=list)
    sdg_indicators: List[SDGIndicator]   = field(default_factory=list)
    metrics:        Dict[str, float]     = field(default_factory=dict)
    pdf_url:        Optional[str]        = None
    generated_by:   str                  = "AI"  # AI | HUMAN
    requested_by:   str                  = ""

    @classmethod
    def request(cls, report_type: str, entity_id: str, entity_type: str,
                requested_by: str, period_start: Optional[date]=None,
                period_end: Optional[date]=None) -> "ImpactReport":
        now = datetime.now(timezone.utc)
        title = f"{report_type.replace('_',' ').title()}, {entity_type} {entity_id[:8]}"
        return cls(id=str(uuid4()), report_type=ReportType(report_type),
                   status=ReportStatus.QUEUED, entity_id=entity_id,
                   entity_type=entity_type, period_start=period_start,
                   period_end=period_end, title=title, requested_by=requested_by,
                   created_at=now, updated_at=now)

    def start_generation(self) -> None:
        self.status = ReportStatus.GENERATING
        self.updated_at = datetime.now(timezone.utc)

    def complete(self, executive_summary: str, sections: List[ReportSection],
                 sdg_indicators: List[SDGIndicator], metrics: Dict[str, float],
                 pdf_url: Optional[str]=None) -> None:
        self.executive_summary = executive_summary
        self.sections          = sections
        self.sdg_indicators    = sdg_indicators
        self.metrics           = metrics
        self.pdf_url           = pdf_url
        self.status            = ReportStatus.READY
        self.updated_at        = datetime.now(timezone.utc)

    def fail(self, reason: str) -> None:
        self.status = ReportStatus.FAILED
        self.metrics["failure_reason"] = reason
        self.updated_at = datetime.now(timezone.utc)
