"""Unit tests for Invoice aggregate."""
import pytest
from datetime import date, timedelta
from src.domain.invoice import Invoice, InvoiceStatus, LineItem
from shared.exceptions import ValidationException, ConflictException


def make_invoice(**kwargs) -> Invoice:
    return Invoice.create(org_id=kwargs.get("org_id","org-1"),
                          currency=kwargs.get("currency","USD"))


class TestInvoiceCreation:
    def test_creates_in_draft_status(self):
        inv = make_invoice()
        assert inv.status == InvoiceStatus.DRAFT
        assert inv.currency == "USD"
        assert inv.total == 0.0
        assert inv.subtotal == 0.0

    def test_default_currency_usd(self):
        inv = Invoice.create("org-1")
        assert inv.currency == "USD"

    def test_stores_period_dates(self):
        inv = Invoice.create("org-1",
            period_start=date(2025,1,1), period_end=date(2025,1,31))
        assert inv.period_start == date(2025,1,1)
        assert inv.period_end   == date(2025,1,31)


class TestLineItems:
    def test_add_line_item_updates_total(self):
        inv = make_invoice()
        inv.add_line_item("Program management fee", quantity=1, unit_price=199.00)
        assert inv.subtotal == pytest.approx(199.00)
        assert inv.total    == pytest.approx(199.00)

    def test_multiple_line_items_sum_correctly(self):
        inv = make_invoice()
        inv.add_line_item("Base fee",        quantity=1,  unit_price=49.00)
        inv.add_line_item("AI verifications",quantity=150,unit_price=0.10)
        inv.add_line_item("Storage GB",      quantity=5,  unit_price=0.50)
        assert inv.subtotal == pytest.approx(49.0 + 15.0 + 2.5)
        assert inv.total    == pytest.approx(66.5)

    def test_tax_applied_to_total(self):
        inv = make_invoice()
        inv.tax_rate = 0.14   # 14% VAT
        inv.add_line_item("Subscription", quantity=1, unit_price=100.00)
        assert inv.tax_amount == pytest.approx(14.00)
        assert inv.total      == pytest.approx(114.00)

    def test_line_item_total_computed(self):
        item = LineItem("Test", quantity=3, unit_price=10.0)
        assert item.total == pytest.approx(30.0)


class TestInvoiceLifecycle:
    def test_issue_sets_issued_status_and_due_date(self):
        inv = make_invoice()
        inv.add_line_item("Fee", 1, 99.0)
        due = date.today() + timedelta(days=30)
        inv.issue(due)
        assert inv.status   == InvoiceStatus.ISSUED
        assert inv.due_date == due

    def test_cannot_issue_empty_invoice(self):
        inv = make_invoice()
        with pytest.raises(ValidationException):
            inv.issue(date.today() + timedelta(days=30))

    def test_mark_paid_sets_paid_status(self):
        inv = make_invoice()
        inv.add_line_item("Fee", 1, 99.0)
        inv.issue(date.today() + timedelta(days=30))
        inv.mark_paid()
        assert inv.status == InvoiceStatus.PAID
        assert inv.paid_at is not None

    def test_cannot_pay_draft_invoice(self):
        inv = make_invoice()
        inv.add_line_item("Fee", 1, 99.0)
        with pytest.raises(ConflictException):
            inv.mark_paid()

    def test_void_draft_invoice(self):
        inv = make_invoice()
        inv.void()
        assert inv.status == InvoiceStatus.VOID

    def test_cannot_void_paid_invoice(self):
        inv = make_invoice()
        inv.add_line_item("Fee", 1, 99.0)
        inv.issue(date.today() + timedelta(days=30))
        inv.mark_paid()
        with pytest.raises(ConflictException):
            inv.void()
