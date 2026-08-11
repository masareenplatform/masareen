from shared.exceptions import NotFoundException, ConflictException
from shared.utils.cqrs import CommandHandler, QueryHandler
from shared.utils.outbox import OutboxWriter
from ..domain.opportunity import Opportunity
from ..domain.platform_content import PlatformPost
from ..infrastructure.postgres_repository import OpportunityRepository
from ..infrastructure.platform_content_repository_impl import SQLAlchemyPlatformContentRepository
from .commands import CreateOpportunityCommand, PublishOpportunityCommand, ApplyToOpportunityCommand, CreatePlatformPostCommand
from .queries import GetOpportunityQuery, ListOpportunitiesQuery, ListPlatformContentQuery

class CreateOpportunityHandler(CommandHandler):
    def __init__(self, repo: OpportunityRepository, session, outbox: OutboxWriter):
        self._repo = repo; self._session = session; self._outbox = outbox
    async def handle(self, cmd: CreateOpportunityCommand) -> dict:
        opp = Opportunity.create(
            org_id=cmd.organization_id, title=cmd.title, opp_type=cmd.opp_type,
            created_by=cmd.organization_id, description=cmd.description,
            country=cmd.country, min_pms_score=cmd.min_pms_score,
            required_skills=cmd.required_skills, deadline=cmd.deadline
        )
        opp.required_sdgs = cmd.required_sdgs or []
        opp.compensation_usd = cmd.compensation_usd
        opp.remote = cmd.remote
        saved = await self._repo.create(opp)
        return {"opportunity_id": saved.id, "status": saved.status.value}

class PublishOpportunityHandler(CommandHandler):
    def __init__(self, repo: OpportunityRepository):
        self._repo = repo
    async def handle(self, cmd: PublishOpportunityCommand) -> dict:
        opp = await self._repo.get(cmd.opportunity_id)
        if not opp: raise NotFoundException("Opportunity", cmd.opportunity_id)
        opp.publish()
        await self._repo.set_status(cmd.opportunity_id, opp.status.value)
        return {"opportunity_id": opp.id, "status": opp.status.value}

class ApplyToOpportunityHandler(CommandHandler):
    def __init__(self, repo: OpportunityRepository):
        self._repo = repo
    async def handle(self, cmd: ApplyToOpportunityCommand) -> dict:
        opp = await self._repo.get(cmd.opportunity_id)
        if not opp: raise NotFoundException("Opportunity", cmd.opportunity_id)

        # Real matching against the applicant's actual PMS, verified skills and
        # SDG experience (read from pms_scores / user_skills / impact_assets).
        profile = await self._repo.get_applicant_profile(cmd.user_id)
        matches, score = opp.matches_profile(
            pms_score=profile["pms_score"],
            skills=profile["skills"],
            sdg_experience=profile["sdg_experience"],
        )
        app_id = await self._repo.apply(cmd.opportunity_id, cmd.user_id, score)
        return {"application_id": app_id, "opportunity_id": cmd.opportunity_id,
                "user_id": cmd.user_id, "status": "SUBMITTED", "eligible": matches, "match_score": score}

class CreatePlatformPostHandler(CommandHandler):
    def __init__(self, repo: SQLAlchemyPlatformContentRepository):
        self._repo = repo
    async def handle(self, cmd: CreatePlatformPostCommand) -> dict:
        post = PlatformPost.create(
            title=cmd.title, body=cmd.body, content_type=cmd.content_type,
            media_url=cmd.media_url, target=cmd.target_audience, budget=cmd.budget
        )
        await self._repo.add_post(post)
        return {"post_id": post.id, "status": "PUBLISHED"}

class GetOpportunityHandler(QueryHandler):
    def __init__(self, repo: OpportunityRepository):
        self._repo = repo
    async def handle(self, q: GetOpportunityQuery):
        return await self._repo.get(q.opportunity_id)

class ListOpportunitiesHandler(QueryHandler):
    def __init__(self, repo: OpportunityRepository):
        self._repo = repo
    async def handle(self, q: ListOpportunitiesQuery):
        return await self._repo.list(q.opp_type, q.country, q.remote, q.min_pms, q.limit, q.offset)

class ListPlatformContentHandler(QueryHandler):
    def __init__(self, repo: SQLAlchemyPlatformContentRepository):
        self._repo = repo
    async def handle(self, q: ListPlatformContentQuery):
        return await self._repo.list_active_posts(q.audience)
