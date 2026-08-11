"""Repository interfaces for workflow aggregates."""
from abc import ABC, abstractmethod
from typing import Optional
from .workflow import WorkflowTemplate, WorkflowInstance


class WorkflowTemplateRepository(ABC):
    @abstractmethod
    async def get_by_id(self, template_id: str) -> Optional[WorkflowTemplate]: ...
    @abstractmethod
    async def save(self, template: WorkflowTemplate) -> WorkflowTemplate: ...


class WorkflowInstanceRepository(ABC):
    @abstractmethod
    async def get_by_id(self, instance_id: str) -> Optional[WorkflowInstance]: ...
    @abstractmethod
    async def save(self, instance: WorkflowInstance) -> WorkflowInstance: ...
