import unittest
from unittest.mock import AsyncMock, MagicMock, patch
import asyncio
import sys
import os

# Ensure the backend root is in sys.path so `shared.*` and `backend.*` resolve
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../../..")))

from backend.ai.verification_orchestrator_service.src.agents.verification_agents import VerificationAgents
from backend.ai.verification_orchestrator_service.src.tasks.verification_tasks import VerificationTasks

AGENTS = "backend.ai.verification_orchestrator_service.src.agents.verification_agents"
TASKS = "backend.ai.verification_orchestrator_service.src.tasks.verification_tasks"


class TestVerificationLogic(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        # Mock LLM to avoid API costs and ensure deterministic tests
        self.mock_llm = MagicMock()
        self.mock_llm.complete = AsyncMock(return_value=MagicMock(text='{"verdict": "APPROVED", "confidence": 0.95}'))

        # Mock BFF Tool
        self.mock_bff = MagicMock()
        self.mock_bff._run = AsyncMock(return_value='{"status": "success"}')

        # Make the lazily-imported crewai Agent/Task return an object that exposes
        # the keyword arguments it was constructed with (role, goal, description...).
        def _capturing_mock(**kwargs):
            m = MagicMock()
            for k, v in kwargs.items():
                setattr(m, k, v)
            return m

        # Patch the lazy optional-dependency helpers so no crewai/langchain import
        # occurs. Patches persist for the whole test (started here, stopped in tearDown).
        self._patchers = [
            patch(f'{AGENTS}._ChatGoogleGenerativeAI', return_value=self.mock_llm),
            patch(f'{AGENTS}.MasarenBffTool', return_value=self.mock_bff),
            patch(f'{AGENTS}._Agent', side_effect=_capturing_mock),
            patch(f'{TASKS}._Task', side_effect=_capturing_mock),
        ]
        for p in self._patchers:
            p.start()

    def tearDown(self):
        for p in self._patchers:
            p.stop()

    async def test_fraud_auditor_goal(self):
        agents = VerificationAgents()
        agent = agents.fraud_auditor_agent()
        self.assertEqual(agent.role, "Fraud Auditor Agent")
        self.assertIn("spatial-temporal", agent.goal)

    async def test_poai_deliberation_task_config(self):
        agents = VerificationAgents()
        tasks = VerificationTasks(agents)
        task = tasks.poai_deliberation_task("ev-123")
        self.assertEqual(task.agent.role, "POAI Deliberation Agent")
        self.assertIn("deliberation", task.description)

if __name__ == "__main__":
    unittest.main()
