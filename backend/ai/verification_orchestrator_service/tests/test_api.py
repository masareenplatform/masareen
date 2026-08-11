import pytest
from fastapi.testclient import TestClient
import sys
import os

# Ensure the backend root is in sys.path so `shared.*` and `backend.*` resolve
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../../..")))

from backend.ai.verification_orchestrator_service.src.main import app
from backend.ai.verification_orchestrator_service.src.utils.blackboard import blackboard

client = TestClient(app)

def test_health_endpoint():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "healthy"}

def test_trigger_verification_success():
    payload = {
        "verification_type": "automated",
        "priority": "high",
        "requested_by": "test-admin",
        "evidence_id": "00000000-0000-0000-0000-000000000123",
    }
    response = client.post("/verify", json=payload)
    assert response.status_code == 200
    assert "ACCEPTED" in response.json()["data"]["status"]

def test_get_report_empty():
    blackboard.clear()
    response = client.get("/report/test-ev-123")
    assert response.status_code == 200
    assert response.json()["data"] == ""
