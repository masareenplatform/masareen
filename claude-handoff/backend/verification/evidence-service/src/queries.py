"""
Evidence Service: Application layer commands and queries.
Handles use cases for evidence management.
"""
from typing import List, Optional, Tuple
from dataclasses import dataclass
from shared.utils.cqrs import Query, QueryHandler

from .domain.evidence import Evidence
from .domain.evidence_repository import EvidenceRepository


@dataclass
class GetEvidenceQuery(Query[Evidence]):
    """Query to retrieve evidence by ID."""
    evidence_id: str


@dataclass
class GetEvidenceByIdHandler(QueryHandler[Evidence]):
    """Handler for GetEvidenceQuery."""
    repo: EvidenceRepository

    async def handle(self, query: GetEvidenceQuery) -> Evidence:
        evidence = await self.repo.get_by_id(query.evidence_id)
        if not evidence:
            from shared.exceptions import NotFoundException
            raise NotFoundException("Evidence", query.evidence_id)
        return evidence


@dataclass
class FindEvidenceByTaskQuery(Query[List[Evidence]]):
    """Query to find evidence by task ID with pagination."""
    task_id: str
    limit: int = 50
    offset: int = 0


@dataclass
class FindEvidenceByTaskHandler(QueryHandler[List[Evidence]]):
    """Handler for FindEvidenceByTaskQuery."""
    repo: EvidenceRepository

    async def handle(self, query: FindEvidenceByTaskQuery) -> Tuple[List[Evidence], int]:
        return await self.repo.list_by_task(query.task_id)


@dataclass
class FindEvidenceBySubmitterQuery(Query[Tuple[List[Evidence], int]]):
    """Query to find evidence by submitter ID with pagination."""
    submitter_id: str
    limit: int = 50
    offset: int = 0


@dataclass
class FindEvidenceBySubmitterHandler(QueryHandler[Tuple[List[Evidence], int]]):
    """Handler for FindEvidenceBySubmitterQuery."""
    repo: EvidenceRepository

    async def handle(self, query: FindEvidenceBySubmitterQuery) -> Tuple[List[Evidence], int]:
        return await self.repo.list_by_submitter(query.submitter_id, query.limit, query.offset)
