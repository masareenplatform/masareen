"""Invoice aggregate, usage-based billing."""
from __future__ import annotations
from dataclasses import dataclass, field
from datetime import date, datetime, timezone
from enum import Enum
from typing import List, Optional
from uuid import uuid4
from shared.base_entity import AggregateRoot
from shared.exceptions import ValidationException, ConflictException


class InvoiceStatus(str, Enum):
    DRAFT   = "DRAFT"
    ISSUED  = "ISSUED"
    PAID    = "PAID"
    OVERDUE = "OVERDUE"
    VOID    = "VOID"


@dataclass
class LineItem:
    description: str
    quantity:    float
    unit_price:  float
    total:       float = 0.0
    def __post_init__(self): self.total = round(self.quantity * self.unit_price, 2)


@dataclass
class Invoice(AggregateRoot):
    organization_id: str              = ""
    status:          InvoiceStatus    = InvoiceStatus.DRAFT
    currency:        str              = "USD"
    line_items:      List[LineItem]   = field(default_factory=list)
    subtotal:        float            = 0.0
    tax_rate:        float            = 0.0
    tax_amount:      float            = 0.0
    total:           float            = 0.0
    due_date:        Optional[date]   = None
    paid_at:         Optional[datetime]= None
    period_start:    Optional[date]   = None
    period_end:      Optional[date]   = None

    @classmethod
    def create(cls, org_id: str, currency: str="USD",
               period_start: Optional[date]=None, period_end: Optional[date]=None) -> "Invoice":
        now = datetime.now(timezone.utc)
        return cls(id=str(uuid4()), organization_id=org_id, currency=currency,
                   period_start=period_start, period_end=period_end,
                   status=InvoiceStatus.DRAFT, created_at=now, updated_at=now)

    def add_line_item(self, description: str, quantity: float, unit_price: float) -> None:
        item = LineItem(description=description, quantity=quantity, unit_price=unit_price)
        self.line_items.append(item)
        self._recalculate()

    def _recalculate(self) -> None:
        self.subtotal   = round(sum(i.total for i in self.line_items), 2)
        self.tax_amount = round(self.subtotal * self.tax_rate, 2)
        self.total      = round(self.subtotal + self.tax_amount, 2)
        self.updated_at = datetime.now(timezone.utc)

    def issue(self, due_date: date) -> None:
        if not self.line_items: raise ValidationException("Cannot issue empty invoice.")
        self.due_date = due_date
        self.status   = InvoiceStatus.ISSUED
        self.updated_at = datetime.now(timezone.utc)

    def mark_paid(self) -> None:
        if self.status != InvoiceStatus.ISSUED:
            raise ConflictException("Only ISSUED invoices can be marked paid.")
        self.status  = InvoiceStatus.PAID
        self.paid_at = datetime.now(timezone.utc)
        self.updated_at = self.paid_at

    def void(self) -> None:
        if self.status == InvoiceStatus.PAID:
            raise ConflictException("Cannot void a paid invoice.")
        self.status = InvoiceStatus.VOID
        self.updated_at = datetime.now(timezone.utc)
