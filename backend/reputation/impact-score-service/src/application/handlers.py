from shared.utils.cqrs import CommandHandler, QueryHandler
from shared.utils.outbox import OutboxWriter
from shared.utils.logging import get_logger
from shared.events.identity_events import PMSUpdated
from ..domain.pms_engine import PMSSnapshot, DIMENSION_KEYS
from ..infrastructure.postgres_repository import PMSRepository
from .commands import UpdatePMSCommand
from .queries import GetPMSQuery, GetPMSHistoryQuery

log = get_logger(__name__)
TOPIC_PMS = "masaren.identity.pms_updated.v1"


def _empty_dimensions() -> dict:
    return {k: 0.0 for k in DIMENSION_KEYS}


class UpdatePMSHandler(CommandHandler):
    def __init__(self, repo: PMSRepository, session, outbox: OutboxWriter):
        self._repo = repo
        self._session = session
        self._outbox = outbox

    async def handle(self, cmd: UpdatePMSCommand) -> dict:
        current = await self._repo.get_latest_snapshot(cmd.user_id)
        base_dims = dict(current.dimensions) if current else _empty_dimensions()
        previous_score = current.composite_score if current else 0.0
        version = current.version if current else 0

        new_dims = PMSSnapshot.apply_delta_to(base_dims, cmd.dimension_deltas)
        snapshot = PMSSnapshot.compute(cmd.user_id, new_dims, version=version)

        saved = await self._repo.save_snapshot(snapshot)

        await self._outbox.write(self._session, PMSUpdated(
            aggregate_id=cmd.user_id,
            previous_score=previous_score,
            new_score=saved.composite_score,
            dimensions=saved.dimensions,
        ), TOPIC_PMS)

        log.info("pms_updated", user_id=cmd.user_id,
                 previous=previous_score, new=saved.composite_score,
                 tier=saved.tier, source=cmd.source)

        return {
            "user_id": saved.user_id,
            "composite_score": saved.composite_score,
            "tier": saved.tier,
            "dimensions": saved.dimensions,
            "version": saved.version,
        }


class GetPMSHandler(QueryHandler):
    def __init__(self, repo: PMSRepository):
        self._repo = repo

    async def handle(self, q: GetPMSQuery):
        snapshot = await self._repo.get_latest_snapshot(q.user_id)
        if not snapshot:
            snapshot = PMSSnapshot.compute(q.user_id, _empty_dimensions())
        return snapshot


class GetPMSHistoryHandler(QueryHandler):
    def __init__(self, repo: PMSRepository):
        self._repo = repo

    async def handle(self, q: GetPMSHistoryQuery):
        return await self._repo.get_history(q.user_id, q.limit)
