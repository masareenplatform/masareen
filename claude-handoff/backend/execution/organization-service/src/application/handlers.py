from shared.exceptions import ConflictException, NotFoundException
from shared.utils.cqrs import CommandHandler, QueryHandler
from shared.utils.outbox import OutboxWriter
from shared.utils.logging import get_logger
from ..domain.organization import Organization
from ..domain.organization_repository import OrganizationRepository
from ..domain.timeline import TimelineEvent
from ..domain.timeline_repository import TimelineRepository
from .commands import (
    CreateOrganizationCommand, VerifyOrganizationCommand, AddMemberCommand, 
    RemoveMemberCommand, SuspendOrganizationCommand, UpdateOrganizationProfileCommand, AddTimelineEventCommand
)
from .queries import GetOrganizationByIdQuery, GetOrganizationBySlugQuery, ListOrganizationsQuery, GetTimelineQuery

log = get_logger(__name__)
TOPIC_ORG = "masaren.execution.organization_created.v1"

class CreateOrganizationHandler(CommandHandler):
    def __init__(self, repo: OrganizationRepository, session, outbox: OutboxWriter):
        self._repo = repo; self._session = session; self._outbox = outbox
    async def handle(self, cmd: CreateOrganizationCommand) -> dict:
        org = Organization.create(cmd.name, cmd.org_type, cmd.country, cmd.created_by, cmd.description, cmd.website)
        if await self._repo.exists_by_slug(org.slug):
            raise ConflictException(f"Organization slug '{org.slug}' already exists.")
        saved = await self._repo.save(org)
        for evt in saved.pull_domain_events():
            await self._outbox.write(self._session, evt, TOPIC_ORG)
        log.info("org_created", org_id=saved.id, name=saved.name)
        return {"org_id": saved.id, "slug": saved.slug, "status": saved.status.value}

class VerifyOrganizationHandler(CommandHandler):
    def __init__(self, repo: OrganizationRepository):
        self._repo = repo
    async def handle(self, cmd: VerifyOrganizationCommand) -> dict:
        org = await self._repo.get_by_id(cmd.org_id)
        if not org: raise NotFoundException("Organization", cmd.org_id)
        org.verify(cmd.admin_id)
        await self._repo.save(org)
        return {"org_id": org.id, "status": org.status.value}

class AddMemberHandler(CommandHandler):
    def __init__(self, repo: OrganizationRepository):
        self._repo = repo
    async def handle(self, cmd: AddMemberCommand) -> dict:
        org = await self._repo.get_by_id(cmd.org_id)
        if not org: raise NotFoundException("Organization", cmd.org_id)
        org.add_member(cmd.user_id)
        await self._repo.save(org)
        return {"org_id": org.id, "user_id": cmd.user_id}

class UpdateOrganizationProfileHandler(CommandHandler):
    def __init__(self, repo: OrganizationRepository):
        self._repo = repo
    async def handle(self, cmd: UpdateOrganizationProfileCommand) -> dict:
        org = await self._repo.get_by_id(cmd.org_id)
        if not org: raise NotFoundException("Organization", cmd.org_id)
        org.update_profile(cmd.profile_data)
        await self._repo.save(org)
        return {"org_id": org.id, "status": "profile_updated"}

class AddTimelineEventHandler(CommandHandler):
    def __init__(self, timeline_repo: TimelineRepository):
        self._timeline_repo = timeline_repo
    async def handle(self, cmd: AddTimelineEventCommand) -> dict:
        event = TimelineEvent(
            entity_id=cmd.entity_id,
            event_type=cmd.event_type,
            title=cmd.title,
            description=cmd.description,
            date=cmd.date if cmd.date else None, # handled in domain with default
            media_url=cmd.media_url,
            metric_value=cmd.metric_value,
            metadata=cmd.metadata or {}
        )
        saved = await self._timeline_repo.add_event(event)
        return {"event_id": saved.id, "entity_id": saved.entity_id}

class GetTimelineHandler(QueryHandler):
    def __init__(self, timeline_repo: TimelineRepository):
        self._timeline_repo = timeline_repo
    async def handle(self, q: GetTimelineQuery):
        return await self._timeline_repo.get_by_entity_id(q.entity_id)

class GetOrganizationByIdHandler(QueryHandler):
    def __init__(self, repo: OrganizationRepository):
        self._repo = repo
    async def handle(self, q: GetOrganizationByIdQuery):
        org = await self._repo.get_by_id(q.org_id)
        if not org: raise NotFoundException("Organization", q.org_id)
        return org

class ListOrganizationsHandler(QueryHandler):
    def __init__(self, repo: OrganizationRepository):
        self._repo = repo
    async def handle(self, q: ListOrganizationsQuery):
        return await self._repo.list_organizations(q.limit, q.offset, q.org_type)
