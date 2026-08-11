"""authorization-service entrypoint."""
from shared.utils.app_factory import create_app
from .api import router

app = create_app(
    service_name="authorization-service",
    version="0.1.0",
    description="RBAC permission enforcement, role management, and policy evaluation.",
    log_level="INFO",
)
app.include_router(router, prefix="/api/v1")
