"""identity-service entrypoint."""
from shared.utils.app_factory import create_app
from shared.utils.health import HealthChecker
from .api.users import router as users_router
from .dependencies import get_publisher, get_settings, get_token_store

settings = get_settings()

health = HealthChecker("identity-service")


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
health.register("redis",    check_redis)

publisher = get_publisher()

app = create_app(
    service_name="identity-service",
    version="0.1.0",
    description="User identity, profiles, skills, Impact Passport, and PMS score management.",
    health_checker=health,
    on_startup=[publisher.start],
    on_shutdown=[publisher.stop],
    log_level="INFO",
)

app.include_router(users_router, prefix="/api/v1")
