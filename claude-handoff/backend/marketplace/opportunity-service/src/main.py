from shared.utils.app_factory import create_app
from .api import router
app = create_app("opportunity-service", "0.1.0",
    "Jobs, funding, scholarships, research, PMS-gated opportunity marketplace.")
app.include_router(router, prefix="/api/v1")
