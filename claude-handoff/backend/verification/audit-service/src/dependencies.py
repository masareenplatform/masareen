from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from shared.utils.cqrs import CommandBus, QueryBus
from shared.utils.outbox import OutboxWriter
from shared.base_repository.db import build_engine, build_session_factory
from .infrastructure.audit_repository_impl import PostgresAuditRepository
from .infrastructure.review_repository_impl import SQLAlchemyReviewRepository
from .application.commands import (
    RecordAuditEventCommand, ExportAuditTrailCommand, 
    RouteToReviewCommand, ResolveReviewCommand
)
from .application.queries import (
    GetAuditTrailQuery, GetPendingReviewsQuery
)
from .application.handlers import (
    RecordAuditEventHandler, ExportAuditTrailHandler,
    RouteToReviewHandler, ResolveReviewHandler,
    GetAuditTrailHandler, GetPendingReviewsHandler
)

engine = build_engine()
session_factory = build_session_factory(engine)

async def get_db_session():
    async with session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()

async def get_command_bus(session: AsyncSession = Depends(get_db_session)) -> CommandBus:
    bus = CommandBus()
    outbox = OutboxWriter()
    audit_repo = PostgresAuditRepository(session)
    review_repo = SQLAlchemyReviewRepository(session)
    bus.register(RecordAuditEventCommand, RecordAuditEventHandler(audit_repo, session, outbox))
    bus.register(ExportAuditTrailCommand, ExportAuditTrailHandler(audit_repo))
    bus.register(RouteToReviewCommand, RouteToReviewHandler(review_repo))
    bus.register(ResolveReviewCommand, ResolveReviewHandler(review_repo))
    return bus

async def get_query_bus(session: AsyncSession = Depends(get_db_session)) -> QueryBus:
    bus = QueryBus()
    audit_repo = PostgresAuditRepository(session)
    review_repo = SQLAlchemyReviewRepository(session)
    bus.register(GetAuditTrailQuery, GetAuditTrailHandler(audit_repo))
    bus.register(GetPendingReviewsQuery, GetPendingReviewsHandler(review_repo))
    return bus
