from shared.utils.app_factory import create_app
from .api import router
app = create_app("notification-service", "0.1.0",
    "Multi-channel notifications: push, email, SMS, in-app.")
app.include_router(router, prefix="/api/v1")
