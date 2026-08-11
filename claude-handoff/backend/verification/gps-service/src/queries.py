"""GPS Query Interfaces - Use cases with validation and business logic."""
from dataclasses import dataclass
from typing import Optional, List
from shared.utils.cqrs import Query


@dataclass
class GetGPSQuery(Query):
    """Query to retrieve GPS record by ID."""
    gps_id: str


@dataclass
class GetGPSByTaskQuery(Query):
    """Query to retrieve GPS records by task ID."""
    task_id: str


@dataclass
class GetGPSByUserQuery(Query):
    """Query to retrieve GPS records by user ID."""
    user_id: str


@dataclass
class GetGPSHistoryQuery(Query):
    """Query to retrieve GPS history with filtering."""
    task_id: Optional[str] = None
    user_id: Optional[str] = None
    media_type: Optional[str] = None
    status: Optional[str] = None
    limit: int = 50
