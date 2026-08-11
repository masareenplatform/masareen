import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "../../.."))

import pytest
from unittest.mock import AsyncMock


@pytest.fixture
def make_uuid():
    from uuid import uuid4
    return lambda: str(uuid4())


@pytest.fixture
def mock_session():
    session = AsyncMock()
    session.execute = AsyncMock()
    session.flush = AsyncMock()
    session.merge = AsyncMock()
    session.commit = AsyncMock()
    return session
