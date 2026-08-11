"""Shared pytest configuration — backend root on sys.path + async session fixture."""
import sys
import os
from unittest.mock import AsyncMock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "../../.."))

import pytest


@pytest.fixture
def mock_session():
    """Mock async SQLAlchemy session."""
    session = AsyncMock()
    session.execute = AsyncMock()
    session.flush = AsyncMock()
    session.merge = AsyncMock()
    session.commit = AsyncMock()
    return session
