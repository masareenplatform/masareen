"""workflow-service entrypoint."""
from shared.utils.app_factory import create_app
from shared.utils.health import HealthChecker
from .api import router

health = HealthChecker("workflow-service")


async def check_postgres():
    from .dependencies import _get_session_factory
    try:
        from sqlalchemy import text
        factory = _get_session_factory()
        async with factory() as s:
            await s.execute(text("SELECT 1"))
        return True
    except Exception:
        return False


health.register("postgres", check_postgres)

app = create_app(
    service_name="workflow-service",
    version="0.1.0",
    description="Multi-step workflow orchestration, dependency graphs, and state machines.",
    health_checker=health,
    log_level="INFO",
)
app.include_router(router, prefix="/api/v1")
