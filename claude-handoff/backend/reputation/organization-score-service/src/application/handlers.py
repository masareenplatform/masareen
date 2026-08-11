from shared.utils.cqrs import CommandHandler, QueryHandler
from shared.utils.outbox import OutboxWriter
from shared.utils.logging import get_logger
from shared.events.reputation_events import OIIUpdated
from ..domain.oii_model import OrganizationalImpactIndex, OIIDimension
from ..infrastructure.postgres_repository import OIIRepository
from .commands import UpdateOIICommand
from .queries import GetOIIQuery, GetOIIHistoryQuery, OIILeaderboardQuery

log = get_logger(__name__)
TOPIC_OII = "masaren.reputation.oii_updated.v1"

DIMENSION_KEYS = OrganizationalImpactIndex.DIMENSION_KEYS
# Equal default weights; overridden from pms_dimension_weights-style config in production.
DEFAULT_WEIGHTS = {k: 0.1 for k in DIMENSION_KEYS}


class UpdateOIIHandler(CommandHandler):
    def __init__(self, repo: OIIRepository, session, outbox: OutboxWriter):
        self._repo = repo
        self._session = session
        self._outbox = outbox

    async def handle(self, cmd: UpdateOIICommand) -> dict:
        current = await self._repo.get_latest(cmd.organization_id)
        previous_index = current["composite_index"] if current else 0.0
        version = (current["version"] if current else 0) + 1

        index = OrganizationalImpactIndex(organization_id=cmd.organization_id)
        index.dimensions = {
            k: OIIDimension(name=k, value=cmd.dimension_values.get(k, 0.0), weight=DEFAULT_WEIGHTS[k])
            for k in DIMENSION_KEYS
        }
        index.version = version
        index.compute_composite()

        dims_values = {k: d.value for k, d in index.dimensions.items()}
        saved = await self._repo.save(cmd.organization_id, index.composite_index, dims_values, version)

        await self._outbox.write(self._session, OIIUpdated(
            aggregate_id=cmd.organization_id,
            previous_index=previous_index,
            new_index=index.composite_index,
            dimensions=dims_values,
        ), TOPIC_OII)

        log.info("oii_updated", organization_id=cmd.organization_id,
                 previous=previous_index, new=index.composite_index)
        return saved


class GetOIIHandler(QueryHandler):
    def __init__(self, repo: OIIRepository):
        self._repo = repo

    async def handle(self, q: GetOIIQuery):
        current = await self._repo.get_latest(q.organization_id)
        if not current:
            return {
                "organization_id": q.organization_id,
                "composite_index": 0.0,
                "tier": "BRONZE",
                "dimensions": {k: 0.0 for k in DIMENSION_KEYS},
                "version": 0,
            }
        return current


class GetOIIHistoryHandler(QueryHandler):
    def __init__(self, repo: OIIRepository):
        self._repo = repo

    async def handle(self, q: GetOIIHistoryQuery):
        return await self._repo.get_history(q.organization_id, q.limit)


class OIILeaderboardHandler(QueryHandler):
    def __init__(self, repo: OIIRepository):
        self._repo = repo

    async def handle(self, q: OIILeaderboardQuery):
        return await self._repo.leaderboard(q.limit)
