"""pytest config for notification-service — backend root on sys.path for `shared`."""
import sys
import os
from unittest.mock import AsyncMock, MagicMock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "../../.."))

import pytest


@pytest.fixture
def mock_session():
    """Mock async SQLAlchemy session."""
    session = AsyncMock()
    session.execute = AsyncMock()
    session.add = MagicMock()
    session.flush = AsyncMock()
    session.merge = AsyncMock()
    session.commit = AsyncMock()
    session.get = AsyncMock()
    session.close = AsyncMock()
    return session
