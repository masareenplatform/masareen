"""Unit tests for ImpactReport aggregate."""
import pytest
from datetime import date
from src.domain.impact_report import ImpactReport, ReportType, ReportStatus, ReportSection, SDGIndicator
from shared.exceptions import ValidationException


class TestImpactReportCreation:
    def test_creates_in_queued_status(self):
        r = ImpactReport.request("PROGRAM_SUMMARY", "prog-1", "PROGRAM", "admin-1")
        assert r.status == ReportStatus.QUEUED
        assert r.report_type == ReportType.PROGRAM_SUMMARY
        assert r.entity_id == "prog-1"

    def test_all_report_types_valid(self):
        for rt in ["INDIVIDUAL_IMPACT","PROGRAM_SUMMARY","ORGANIZATION_ANNUAL",
                   "SDG_PROGRESS","DONOR_REPORT","ESG_COMPLIANCE"]:
            r = ImpactReport.request(rt, "eid", "PROGRAM", "admin")
            assert r.report_type.value == rt

    def test_period_dates_stored(self):
        r = ImpactReport.request("PROGRAM_SUMMARY", "p1", "PROGRAM", "admin",
            period_start=date(2025, 1, 1), period_end=date(2025, 12, 31))
        assert r.period_start == date(2025, 1, 1)
        assert r.period_end   == date(2025, 12, 31)


class TestImpactReportLifecycle:
    def test_start_generation_changes_status(self):
        r = ImpactReport.request("PROGRAM_SUMMARY", "p1", "PROGRAM", "admin")
        r.start_generation()
        assert r.status == ReportStatus.GENERATING

    def test_complete_sets_ready_and_stores_content(self):
        r = ImpactReport.request("PROGRAM_SUMMARY", "p1", "PROGRAM", "admin")
        r.start_generation()
        sections = [ReportSection(title="Overview", content="This program reached 500 people.")]
        sdgs = [SDGIndicator(goal=3, indicator_code="3.1.1", value=42.0,
                             unit="percent", description="Maternal mortality ratio reduced")]
        r.complete("Executive summary here.", sections, sdgs,
                   {"tasks_completed": 50, "volunteers": 12}, "https://cdn.masaren.io/report.pdf")
        assert r.status == ReportStatus.READY
        assert r.executive_summary == "Executive summary here."
        assert len(r.sections) == 1
        assert len(r.sdg_indicators) == 1
        assert r.pdf_url is not None
        assert r.metrics["tasks_completed"] == 50

    def test_fail_sets_failed_status(self):
        r = ImpactReport.request("PROGRAM_SUMMARY", "p1", "PROGRAM", "admin")
        r.start_generation()
        r.fail("LLM timeout after 60s")
        assert r.status == ReportStatus.FAILED
        assert "failure_reason" in r.metrics
