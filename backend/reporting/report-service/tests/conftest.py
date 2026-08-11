"""Shared pytest configuration — uses shared kernel test fixtures."""
import sys
import os
from unittest.mock import AsyncMock, MagicMock

# Add backend root to Python path so 'shared' imports work
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "../../.."))

import pytest


@pytest.fixture
def make_uuid():
    from uuid import uuid4
    return lambda: str(uuid4())


@pytest.fixture
def mock_session():
    """Mock async SQLAlchemy session."""
    session = AsyncMock()
    session.execute = AsyncMock()
    session.flush = AsyncMock()
    session.merge = AsyncMock()
    session.commit = AsyncMock()
    return session
