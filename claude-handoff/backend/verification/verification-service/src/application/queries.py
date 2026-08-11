"""Application layer queries and query handlers for verification domain."""
from typing import List, Optional, Dict, Any
from shared.utils.cqrs import Query, QueryHandler

from shared.utils.logging import get_logger

log = get_logger(__name__)


class GetEvidenceByIdQuery(Query):
    """Query to get evidence by ID."""
    def __init__(self, evidence_id: str):
        if not evidence_id:
            raise ValueError("evidence_id is required")
        self.evidence_id = evidence_id


class FindEvidenceByTaskQuery(Query):
    """Query to find evidence by task ID."""
    def __init__(self, task_id: str):
        if not task_id:
            raise ValueError("task_id is required")
        self.task_id = task_id


class GetVerificationPipelineByIdQuery(Query):
    """Query to get verification pipeline by ID."""
    def __init__(self, pipeline_id: str):
        if not pipeline_id:
            raise ValueError("pipeline_id is required")
        self.pipeline_id = pipeline_id


class GetPipelineByEvidenceIdQuery(Query):
    """Query to get verification pipeline by evidence ID."""
    def __init__(self, evidence_id: str):
        if not evidence_id:
            raise ValueError("evidence_id is required")
        self.evidence_id = evidence_id


class ListPendingVerificationPipelinesQuery(Query):
    """Query to list all pending verification pipelines."""
    pass


class GetReviewQueueQuery(Query):
    """Query to get human review queue."""
    def __init__(self, limit: int = 20):
        self.limit = limit


class GetEvidenceByIdHandler(QueryHandler):
    def __init__(self, evidence_repository):
        self.evidence_repository = evidence_repository

    async def handle(self, query: GetEvidenceByIdQuery) -> Optional[dict]:
        record = await self.evidence_repository.get_by_id(query.evidence_id)
        if not record:
            return None
        return {"id": record.id, "evidence_id": record.evidence_id, "task_id": record.task_id,
                "status": record.status.value, "submitted_by": record.submitted_by}


class FindEvidenceByTaskHandler(QueryHandler):
    def __init__(self, evidence_repository):
        self.evidence_repository = evidence_repository

    async def handle(self, query: FindEvidenceByTaskQuery) -> List[dict]:
        results = await self.evidence_repository.list_by_task(query.task_id)
        return [{"id": r.id, "evidence_id": r.evidence_id, "status": r.status.value} for r in results]


class GetVerificationPipelineByIdHandler(QueryHandler):
    def __init__(self, pipeline_repository):
        self.pipeline_repository = pipeline_repository

    async def handle(self, query: GetVerificationPipelineByIdQuery) -> Optional[dict]:
        p = await self.pipeline_repository.get_by_id(query.pipeline_id)
        if not p:
            return None
        return {"pipeline_id": p.pipeline_id, "evidence_id": p.evidence_id, "status": p.status.value,
                "assigned_reviewer": p.assigned_reviewer}


class GetPipelineByEvidenceIdHandler(QueryHandler):
    def __init__(self, pipeline_repository):
        self.pipeline_repository = pipeline_repository

    async def handle(self, query: GetPipelineByEvidenceIdQuery) -> Optional[dict]:
        p = await self.pipeline_repository.get_by_evidence_id(query.evidence_id)
        if not p:
            return None
        return {"pipeline_id": p.pipeline_id, "evidence_id": p.evidence_id, "status": p.status.value}


class ListPendingVerificationPipelinesHandler(QueryHandler):
    def __init__(self, pipeline_repository):
        self.pipeline_repository = pipeline_repository

    async def handle(self, query: ListPendingVerificationPipelinesQuery) -> List[dict]:
        pipelines = await self.pipeline_repository.list_pending()
        return [{"pipeline_id": p.pipeline_id, "status": p.status.value} for p in pipelines]


class GetReviewQueueHandler(QueryHandler):
    def __init__(self, pipeline_repository):
        self.pipeline_repository = pipeline_repository

    async def handle(self, query: GetReviewQueueQuery) -> List[dict]:
        pipelines = await self.pipeline_repository.list_pending()
        human_review = [p for p in pipelines if p.requires_human_review]
        return [{"pipeline_id": p.pipeline_id, "status": p.status.value,
                 "assigned_reviewer": p.assigned_reviewer} for p in human_review[:query.limit]]
