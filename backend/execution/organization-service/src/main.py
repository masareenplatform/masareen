from shared.utils.app_factory import create_app
from .api import router
app = create_app("organization-service", "0.1.0",
    "Organization profiles, verification, OII score aggregation.")
app.include_router(router, prefix="/api/v1")
