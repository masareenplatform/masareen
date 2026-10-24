"""Shared pytest configuration, uses shared kernel test fixtures."""
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "../../.."))

import pytest


@pytest.fixture
def make_uuid():
    from uuid import uuid4
    return lambda: str(uuid4())


@pytest.fixture
def mock_session(mocker):
    """Mock async SQLAlchemy session."""
    session = mocker.AsyncMock()
    session.execute = mocker.AsyncMock()
    session.flush   = mocker.AsyncMock()
    session.merge   = mocker.AsyncMock()
    session.commit  = mocker.AsyncMock()
    return session
