from shared.utils.app_factory import create_app
from .api import router
app = create_app("analytics-service", "0.1.0", "Real-time impact analytics, platform, program, org, user stats.")
app.include_router(router, prefix="/api/v1")
