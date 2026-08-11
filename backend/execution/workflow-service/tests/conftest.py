"""Shared pytest configuration — uses shared kernel test fixtures."""
import sys
import os

# Add backend root to Python path so 'shared' imports work
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "../../.."))

import pytest


@pytest.fixture
def make_uuid():
    from uuid import uuid4
    return lambda: str(uuid4())
