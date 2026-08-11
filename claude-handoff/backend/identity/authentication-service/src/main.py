"""authentication-service entrypoint."""
from shared.utils.app_factory import create_app
from shared.utils.health import HealthChecker
from .api import router
from .dependencies import get_token_store, get_settings

settings = get_settings()
health = HealthChecker("authentication-service")


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


async def check_redis():
    return await get_token_store().ping()


health.register("postgres", check_postgres)
health.register("redis", check_redis)

app = create_app(
    service_name="authentication-service",
    version="0.1.0",
    description="JWT authentication, refresh tokens, password management, and session lifecycle.",
    health_checker=health,
    log_level="INFO",
)
app.include_router(router, prefix="/api/v1")
