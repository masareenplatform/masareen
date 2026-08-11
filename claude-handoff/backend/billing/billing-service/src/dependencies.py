from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession
from shared.utils.cqrs import CommandBus, QueryBus
from shared.utils.outbox import OutboxWriter
from .infrastructure.database import get_session as get_db_session
from .infrastructure.postgres_repository import InvoiceRepository
from .application.commands import CreateInvoiceCommand, IssueInvoiceCommand, MarkInvoicePaidCommand
from .application.queries import GetInvoiceQuery, ListOrgInvoicesQuery
from .application.handlers import (
    CreateInvoiceHandler, IssueInvoiceHandler, MarkInvoicePaidHandler,
    GetInvoiceHandler, ListOrgInvoicesHandler
)


async def get_command_bus(session: AsyncSession = Depends(get_db_session)) -> CommandBus:
    bus = CommandBus()
    outbox = OutboxWriter()
    repo = InvoiceRepository(session)
    bus.register(CreateInvoiceCommand, CreateInvoiceHandler(repo, session, outbox))
    bus.register(IssueInvoiceCommand, IssueInvoiceHandler(repo))
    bus.register(MarkInvoicePaidCommand, MarkInvoicePaidHandler(repo))
    return bus

async def get_query_bus(session: AsyncSession = Depends(get_db_session)) -> QueryBus:
    bus = QueryBus()
    repo = InvoiceRepository(session)
    bus.register(GetInvoiceQuery, GetInvoiceHandler(repo))
    bus.register(ListOrgInvoicesQuery, ListOrgInvoicesHandler(repo))
    return bus
