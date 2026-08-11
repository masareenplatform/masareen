"""
Submission service query bus for finding submission bundles.
"""
from __future__ import annotations
from abc import ABC, abstractmethod
from typing import Generic, List, TypeVar

T = TypeVar("T")


class FindSubmissionsByTaskQuery:
    """Find submission bundles by task ID."""
    def __init__(self, task_id: str):
        self.task_id = task_id


class FindSubmissionsBySubmitterQuery:
    """Find submission bundles by submitter ID with pagination."""
    def __init__(self, user_id: str, limit: int = 10, offset: int = 0):
        self.user_id = user_id
        self.limit = limit
        self.offset = offset


class GetSubmissionQuery:
    """Get submission bundle by ID."""
    def __init__(self, submission_id: str):
        self.submission_id = submission_id
