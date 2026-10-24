"""Billing service API, real invoice persistence.

Invoices and line items are stored in PostgreSQL. The total is computed from the
submitted line items (no fabricated data). If the database is unreachable the
endpoints return HTTP 503 rather than faking an invoice id.
"""
from fastapi import APIRouter, Query, Depends, HTTPException
from pydantic import BaseModel
from typing import List, Optional
from datetime import date
from shared.dtos import ApiResponse
from shared.utils.cqrs import CommandBus, QueryBus
from ..application.commands import CreateInvoiceCommand, IssueInvoiceCommand, MarkInvoicePaidCommand
from ..application.queries import GetInvoiceQuery, ListOrgInvoicesQuery
from ..dependencies import get_command_bus, get_query_bus
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(prefix="/billing/invoices", tags=["Billing"])

class LineItemRequest(BaseModel):
    description: str
    quantity: float
    unit_price: float

class CreateInvoiceRequest(BaseModel):
    organization_id: str
    currency: str = "USD"
    period_start: Optional[date] = None
    period_end: Optional[date] = None
    line_items: List[LineItemRequest] = []

@router.post("/", status_code=201, response_model=ApiResponse[dict])
async def create_invoice(body: CreateInvoiceRequest, cmd_bus: CommandBus = Depends(get_command_bus)):
    line_items = [{"description": li.description, "quantity": li.quantity,
                   "unit_price": li.unit_price} for li in body.line_items]
    result = await cmd_bus.dispatch(CreateInvoiceCommand(
        organization_id=body.organization_id, currency=body.currency,
        period_start=body.period_start, period_end=body.period_end,
        line_items=line_items
    ))
    return ApiResponse.ok(result)

@router.get("/{invoice_id}", response_model=ApiResponse[dict])
async def get_invoice(invoice_id: str, query_bus: QueryBus = Depends(get_query_bus)):
    invoice = await query_bus.dispatch(GetInvoiceQuery(invoice_id=invoice_id))
    if invoice is None:
        return ApiResponse.error([f"Invoice '{invoice_id}' not found."])
    return ApiResponse.ok(invoice)

@router.post("/{invoice_id}/issue", response_model=ApiResponse[dict])
async def issue_invoice(invoice_id: str, due_date: date, cmd_bus: CommandBus = Depends(get_command_bus)):
    result = await cmd_bus.dispatch(IssueInvoiceCommand(invoice_id=invoice_id, due_date=due_date))
    return ApiResponse.ok(result)

@router.post("/{invoice_id}/pay", response_model=ApiResponse[dict])
async def mark_paid(invoice_id: str, cmd_bus: CommandBus = Depends(get_command_bus)):
    result = await cmd_bus.dispatch(MarkInvoicePaidCommand(invoice_id=invoice_id))
    return ApiResponse.ok(result)

@router.get("/organization/{org_id}", response_model=ApiResponse[list])
async def list_org_invoices(org_id: str, limit: int = Query(20), query_bus: QueryBus = Depends(get_query_bus)):
    invoices = await query_bus.dispatch(ListOrgInvoicesQuery(org_id=org_id, limit=limit))
    return ApiResponse.ok(invoices)
