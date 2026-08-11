from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession
from shared.utils.cqrs import CommandBus, QueryBus
from shared.utils.outbox import OutboxWriter
from .infrastructure.database import get_session as get_db_session
from .infrastructure.postgres_repository import OpportunityRepository
from .infrastructure.platform_content_repository_impl import SQLAlchemyPlatformContentRepository
from .application.commands import (
    CreateOpportunityCommand, PublishOpportunityCommand, ApplyToOpportunityCommand, CreatePlatformPostCommand
)
from .application.queries import GetOpportunityQuery, ListOpportunitiesQuery, ListPlatformContentQuery
from .application.handlers import (
    CreateOpportunityHandler, PublishOpportunityHandler, ApplyToOpportunityHandler,
    CreatePlatformPostHandler, GetOpportunityHandler, ListOpportunitiesHandler, ListPlatformContentHandler
)


async def get_command_bus(session: AsyncSession = Depends(get_db_session)) -> CommandBus:
    bus = CommandBus()
    outbox = OutboxWriter()
    opp_repo = OpportunityRepository(session)
    content_repo = SQLAlchemyPlatformContentRepository(session)
    bus.register(CreateOpportunityCommand, CreateOpportunityHandler(opp_repo, session, outbox))
    bus.register(PublishOpportunityCommand, PublishOpportunityHandler(opp_repo))
    bus.register(ApplyToOpportunityCommand, ApplyToOpportunityHandler(opp_repo))
    bus.register(CreatePlatformPostCommand, CreatePlatformPostHandler(content_repo))
    return bus

async def get_query_bus(session: AsyncSession = Depends(get_db_session)) -> QueryBus:
    bus = QueryBus()
    opp_repo = OpportunityRepository(session)
    content_repo = SQLAlchemyPlatformContentRepository(session)
    bus.register(GetOpportunityQuery, GetOpportunityHandler(opp_repo))
    bus.register(ListOpportunitiesQuery, ListOpportunitiesHandler(opp_repo))
    bus.register(ListPlatformContentQuery, ListPlatformContentHandler(content_repo))
    return bus
