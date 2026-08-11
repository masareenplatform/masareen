from shared.utils.app_factory import create_app
from .api import router
app = create_app("report-service", "0.1.0",
    "AI-generated SDG-aligned impact reports for individuals, programs, and organizations.")
app.include_router(router, prefix="/api/v1")
