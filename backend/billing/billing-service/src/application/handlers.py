from shared.exceptions import NotFoundException, ValidationException
from shared.utils.cqrs import CommandHandler, QueryHandler
from shared.utils.outbox import OutboxWriter
from ..domain.invoice import Invoice
from ..infrastructure.postgres_repository import InvoiceRepository
from .commands import CreateInvoiceCommand, IssueInvoiceCommand, MarkInvoicePaidCommand
from .queries import GetInvoiceQuery, ListOrgInvoicesQuery


class CreateInvoiceHandler(CommandHandler):
    def __init__(self, repo: InvoiceRepository, session, outbox: OutboxWriter):
        self._repo = repo
        self._session = session
        self._outbox = outbox

    async def handle(self, cmd: CreateInvoiceCommand) -> dict:
        # Build the aggregate first so domain rules/calculations apply, then persist.
        invoice = Invoice.create(cmd.organization_id, cmd.currency, cmd.period_start, cmd.period_end)
        for item in cmd.line_items:
            invoice.add_line_item(item["description"], item["quantity"], item["unit_price"])
        line_items = [
            {"description": li.description, "quantity": li.quantity,
             "unit_price": li.unit_price, "total": li.total}
            for li in invoice.line_items
        ]
        return await self._repo.create_invoice(
            cmd.organization_id, cmd.currency, cmd.period_start, cmd.period_end, line_items)


class IssueInvoiceHandler(CommandHandler):
    def __init__(self, repo: InvoiceRepository):
        self._repo = repo

    async def handle(self, cmd: IssueInvoiceCommand) -> dict:
        ok = await self._repo.set_status(cmd.invoice_id, "ISSUED", cmd.due_date)
        if not ok:
            raise NotFoundException("Invoice", cmd.invoice_id)
        return {"invoice_id": cmd.invoice_id, "status": "ISSUED", "due_date": str(cmd.due_date)}


class MarkInvoicePaidHandler(CommandHandler):
    def __init__(self, repo: InvoiceRepository):
        self._repo = repo

    async def handle(self, cmd: MarkInvoicePaidCommand) -> dict:
        ok = await self._repo.set_status(cmd.invoice_id, "PAID")
        if not ok:
            raise NotFoundException("Invoice", cmd.invoice_id)
        return {"invoice_id": cmd.invoice_id, "status": "PAID"}


class GetInvoiceHandler(QueryHandler):
    def __init__(self, repo: InvoiceRepository):
        self._repo = repo

    async def handle(self, q: GetInvoiceQuery):
        return await self._repo.get_invoice(q.invoice_id)


class ListOrgInvoicesHandler(QueryHandler):
    def __init__(self, repo: InvoiceRepository):
        self._repo = repo

    async def handle(self, q: ListOrgInvoicesQuery):
        return await self._repo.list_org_invoices(q.org_id, q.limit)
