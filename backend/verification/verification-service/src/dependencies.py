from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession
from .application.command_bus import CommandBus, QueryBus
from shared.utils.outbox import OutboxWriter
from shared.base_repository.db import build_engine, build_session_factory
from .infrastructure.postgres_repositories import (
    PostgresEvidenceRepository,
    PostgresVerificationPipelineRepository,
)
from .application.commands import (
    StartVerificationPipelineCommand,
    RecordAIVerificationResultCommand,
    StartFraudCheckCommand,
    StartHumanReviewCommand,
    RecordHumanVerdictCommand,
    SubmitVerificationCommand,
)
from .application.queries import (
    GetVerificationPipelineByIdQuery,
    GetPipelineByEvidenceIdQuery,
    ListPendingVerificationPipelinesQuery,
    GetReviewQueueQuery,
    GetEvidenceByIdHandler,
    FindEvidenceByTaskHandler,
    GetVerificationPipelineByIdHandler,
    GetPipelineByEvidenceIdHandler,
    ListPendingVerificationPipelinesHandler,
    GetReviewQueueHandler,
)
from .application.handlers import (
    StartVerificationPipelineHandler,
    RecordAIVerificationHandler,
    StartFraudCheckHandler,
    StartHumanReviewHandler,
    RecordHumanVerdictHandler,
    SubmitVerificationHandler,
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
    evidence_repo = PostgresEvidenceRepository(session)
    pipeline_repo = PostgresVerificationPipelineRepository(session)
    bus.register_handler(StartVerificationPipelineCommand,
                         StartVerificationPipelineHandler(evidence_repo, pipeline_repo, outbox))
    bus.register_handler(RecordAIVerificationResultCommand,
                         RecordAIVerificationHandler(evidence_repo, pipeline_repo, outbox))
    bus.register_handler(StartFraudCheckCommand,
                         StartFraudCheckHandler(pipeline_repo, evidence_repo))
    bus.register_handler(StartHumanReviewCommand,
                         StartHumanReviewHandler(pipeline_repo, evidence_repo))
    bus.register_handler(RecordHumanVerdictCommand,
                         RecordHumanVerdictHandler(evidence_repo, pipeline_repo, outbox))
    bus.register_handler(SubmitVerificationCommand,
                         SubmitVerificationHandler(evidence_repo))
    return bus

async def get_query_bus(session: AsyncSession = Depends(get_db_session)) -> QueryBus:
    bus = QueryBus()
    evidence_repo = PostgresEvidenceRepository(session)
    pipeline_repo = PostgresVerificationPipelineRepository(session)
    bus.register_handler(GetVerificationPipelineByIdQuery,
                         GetVerificationPipelineByIdHandler(pipeline_repo))
    bus.register_handler(GetPipelineByEvidenceIdQuery,
                         GetPipelineByEvidenceIdHandler(pipeline_repo))
    bus.register_handler(ListPendingVerificationPipelinesQuery,
                         ListPendingVerificationPipelinesHandler(pipeline_repo))
    bus.register_handler(GetReviewQueueQuery,
                         GetReviewQueueHandler(pipeline_repo))
    return bus
