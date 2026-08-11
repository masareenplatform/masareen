from shared.utils.app_factory import create_app
from .api import router
app = create_app("subscription-service", "0.1.0", "Plan management, tier enforcement, feature gating.")
app.include_router(router, prefix="/api/v1")
