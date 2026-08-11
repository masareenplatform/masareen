"""Unit tests for the Workflow aggregate — no DB, no I/O."""
import pytest

from src.domain.workflow import WorkflowInstance, WorkflowTemplate, WorkflowStep


class TestWorkflowDomain:
    def test_workflow_progress_tracking(self):
        tmpl = WorkflowTemplate(id="t1", name="Field Survey",
            description=None, created_by="admin")
        tmpl.steps = [
            WorkflowStep(id="s1", name="Arrive", order=1),
            WorkflowStep(id="s2", name="Survey", order=2, depends_on=["s1"]),
            WorkflowStep(id="s3", name="Report", order=3, depends_on=["s2"]),
        ]
        inst = WorkflowInstance.instantiate(tmpl, "prog-1", "user-1")
        inst.start()
        assert inst.progress_percent == 0.0
        inst.advance_step(inst.steps[0].id)
        assert inst.progress_percent == pytest.approx(33.3, 0.1)
        inst.advance_step(inst.steps[1].id)
        inst.advance_step(inst.steps[2].id)
        assert inst.status.value == "COMPLETED"
        assert inst.progress_percent == 100.0
