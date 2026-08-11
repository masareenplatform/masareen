"""Reporting service API — real, SDG-aligned impact report generation.

All metrics are computed by ``ReportRepository`` from the platform's relational
tables and persisted in ``impact_reports``. For COMPREHENSIVE reports, an
optional cloud-LLM narrative is synthesised strictly from those real metrics.
No fabricated data, no sample content, no placeholder keys.
"""
import os
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from typing import Optional
from sqlalchemy.ext.asyncio import AsyncSession

from shared.dtos import ApiResponse
from shared.utils.logging import get_logger
from shared.utils.cloud_llm_client import build_llm_client
from ..infrastructure.database import get_session
from ..infrastructure.postgres_repository import ReportRepository
from ..infrastructure.billing_client import PaymentServiceClient
from ..application.report_generator import ReportGenerator

log = get_logger(__name__)
router = APIRouter(prefix="/reports", tags=["Reports"])

# Build the LLM client only when a real key is configured. No placeholder keys:
# without a key, reports are still generated from real metrics (deterministic
# narrative) — COMPREHENSIVE simply skips AI enrichment.
_llm_key = os.getenv("LLM_API_KEY")
_llm_client = build_llm_client(provider=os.getenv("LLM_PROVIDER", "google"),
                               api_key=_llm_key) if _llm_key else None
generator = ReportGenerator(_llm_client)

# Real billing integration for paid-tier gating (handoff gap S-002 6.4).
# Points at the payment-service local ledger; no external PSP is stubbed.
_billing = PaymentServiceClient(os.getenv("PAYMENT_SERVICE_URL", "http://masaren-payment:8030"))

# Public target type -> (entity_type, report_type)
_TARGET_MAP = {
    "PERSON":       ("USER", "INDIVIDUAL_IMPACT"),
    "USER":         ("USER", "INDIVIDUAL_IMPACT"),
    "ORGANIZATION": ("ORGANIZATION", "ORGANIZATION_ANNUAL"),
    "PROGRAM":      ("PROGRAM", "PROGRAM_SUMMARY"),
}


class ReportRequest(BaseModel):
    target_id: str
    target_type: str  # PERSON | ORGANIZATION | PROGRAM
    tier: str = "BASIC"  # BASIC | COMPREHENSIVE
    requested_by: Optional[str] = None


class PurchaseRequest(BaseModel):
    organization_id: str
    amount_usd: float = 4.99  # real paid-tier price (never a fake "SUCCESS")


def _repo(session: AsyncSession) -> ReportRepository:
    return ReportRepository(session)


@router.post("/generate", response_model=ApiResponse[dict])
async def generate_report(req: ReportRequest, session: AsyncSession = Depends(get_session)):
    mapping = _TARGET_MAP.get(req.target_type.upper())
    if not mapping:
        raise HTTPException(status_code=400, detail=f"Unsupported target_type '{req.target_type}'")
    entity_type, report_type = mapping
    repo = _repo(session)
    try:
        requested = await repo.request_report(
            report_type=report_type, entity_id=req.target_id,
            entity_type=entity_type, requested_by=req.requested_by or req.target_id)
        report = await repo.generate_report(requested.id)  # real metrics + persistence

        if req.tier == "COMPREHENSIVE":
            narrative = await generator.synthesize_narrative(
                report.entity_id, report.entity_type, req.tier, report.metrics)
            await repo.update_summary(report.id, narrative)
            report.executive_summary = narrative

        return ApiResponse.ok({
            "report_id": report.id,
            "status": report.status.value,
            "tier": req.tier,
            "entity_type": report.entity_type,
            "entity_id": report.entity_id,
            "metrics": report.metrics,
            "executive_summary": report.executive_summary,
            "sdg_indicators": [s.__dict__ for s in report.sdg_indicators],
        })
    except Exception as e:
        log.error("report_generation_failed", target_id=req.target_id, error=str(e))
        raise HTTPException(status_code=503, detail=f"report_store_unavailable: {e}")


@router.get("/{report_id}", response_model=ApiResponse[dict])
async def get_report(report_id: str, session: AsyncSession = Depends(get_session)):
    data = await _repo(session).get_report(report_id)
    if data is None:
        raise HTTPException(status_code=404, detail=f"Report '{report_id}' not found")
    # Normalise UUID/datetime for JSON
    return ApiResponse.ok({k: (str(v) if not isinstance(v, (str, int, float, list, dict, type(None))) else v)
                           for k, v in data.items()})


@router.post("/{report_id}/purchase", status_code=200, response_model=ApiResponse[dict])
async def purchase_report(report_id: str, body: PurchaseRequest,
                         session: AsyncSession = Depends(get_session)):
    """Paid-tier gating via the REAL payment-service local ledger.

    Creates a real payment intent (CAPTURED in the local ledger) and, only
    on success, marks the report paid. If billing is unreachable the report
    stays unpaid and we return 503 — never a fabricated "SUCCESS".
    """
    repo = _repo(session)
    existing = await repo.get_report(report_id)
    if existing is None:
        raise HTTPException(status_code=404, detail=f"Report '{report_id}' not found")
    if await repo.is_paid(report_id):
        return ApiResponse.ok({"report_id": report_id, "status": "already_paid"})
    try:
        intent = await _billing.create_intent(
            invoice_id=None, org_id=body.organization_id,
            amount_usd=body.amount_usd, payment_method_id=None,
        )
    except Exception as e:
        log.error("report_purchase_billing_failed", report_id=report_id, error=str(e))
        raise HTTPException(status_code=503, detail=f"billing_unavailable: {e}")
    payment_id = intent.get("id") if isinstance(intent, dict) else None
    if not payment_id:
        raise HTTPException(status_code=502, detail="billing_returned_no_payment_id")
    await repo.mark_paid(report_id, payment_id)
    return ApiResponse.ok({
        "report_id": report_id,
        "status": "paid",
        "payment_id": payment_id,
        "amount_usd": body.amount_usd,
    })
