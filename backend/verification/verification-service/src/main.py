"""Verification Service main application factory."""
import sys, os; sys.path.insert(0, os.path.join(os.path.dirname(__file__), "../../.."))
from shared.utils.app_factory import create_app
from shared.utils.logging import get_logger
from .api import router

log = get_logger(__name__)

app = create_app(
    "verification-service",
    "0.1.0",
    "Multi-stage evidence verification pipeline with AI review, fraud detection, human review."
)
app.include_router(router, prefix="/api/v1")
