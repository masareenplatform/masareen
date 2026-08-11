from shared.exceptions import NotFoundException
from shared.utils.cqrs import CommandHandler, QueryHandler
from shared.utils.outbox import OutboxWriter
from shared.utils.logging import get_logger
from ..domain.program import Program
from ..domain.program_repository import ProgramRepository
from .commands import CreateProgramCommand, PublishProgramCommand, ActivateProgramCommand, EnrollParticipantCommand, AddMilestoneCommand
from .queries import GetProgramByIdQuery, ListProgramsByOrgQuery, ListProgramsQuery

log = get_logger(__name__)
TOPIC = "masaren.execution.program_created.v1"

class CreateProgramHandler(CommandHandler):
    def __init__(self, repo: ProgramRepository, session, outbox: OutboxWriter):
        self._repo=repo; self._session=session; self._outbox=outbox
    async def handle(self, cmd: CreateProgramCommand) -> dict:
        p = Program.create(cmd.organization_id, cmd.title, cmd.created_by,
            cmd.description, cmd.sdg_goals, cmd.country, cmd.start_date, cmd.end_date, cmd.max_participants)
        saved = await self._repo.save(p)
        for evt in saved.pull_domain_events():
            await self._outbox.write(self._session, evt, TOPIC)
        log.info("program_created", program_id=saved.id, org_id=saved.organization_id)
        return {"program_id": saved.id, "status": saved.status.value}

class PublishProgramHandler(CommandHandler):
    def __init__(self, repo: ProgramRepository):
        self._repo=repo
    async def handle(self, cmd: PublishProgramCommand) -> dict:
        p = await self._repo.get_by_id(cmd.program_id)
        if not p: raise NotFoundException("Program", cmd.program_id)
        p.publish(); await self._repo.save(p)
        return {"program_id": p.id, "status": p.status.value}

class EnrollParticipantHandler(CommandHandler):
    def __init__(self, repo: ProgramRepository):
        self._repo=repo
    async def handle(self, cmd: EnrollParticipantCommand) -> dict:
        p = await self._repo.get_by_id(cmd.program_id)
        if not p: raise NotFoundException("Program", cmd.program_id)
        p.enroll_participant(); await self._repo.save(p)
        return {"program_id": p.id, "enrolled_count": p.enrolled_count}

class GetProgramByIdHandler(QueryHandler):
    def __init__(self, repo: ProgramRepository):
        self._repo=repo
    async def handle(self, q: GetProgramByIdQuery):
        p = await self._repo.get_by_id(q.program_id)
        if not p: raise NotFoundException("Program", q.program_id)
        return p

class ListProgramsHandler(QueryHandler):
    def __init__(self, repo: ProgramRepository):
        self._repo=repo
    async def handle(self, q: ListProgramsQuery):
        return await self._repo.list_programs(q.limit, q.offset, q.status, q.country)
