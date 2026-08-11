from dataclasses import dataclass
from datetime import date
from typing import List, Optional
from shared.utils.cqrs import Command

@dataclass
class CreateInvoiceCommand(Command):
    organization_id: str
    currency: str
    period_start: Optional[date]
    period_end: Optional[date]
    line_items: List[dict]

@dataclass
class IssueInvoiceCommand(Command):
    invoice_id: str
    due_date: date

@dataclass
class MarkInvoicePaidCommand(Command):
    invoice_id: str
