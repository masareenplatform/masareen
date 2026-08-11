"""social-service entrypoint.

Owns the Impact Feed posts, likes and bookmarks — the real backend behind the
web/mobile social UIs (previously client-side mocks). Follows the repo's
service conventions: ``create_app`` + ``ApiResponse`` envelope + ``/api/v1``
prefix + ``/health``.
"""
from shared.utils.app_factory import create_app
from shared.utils.health import HealthChecker

from .api import router
from .db import init_db

health = HealthChecker("social-service")


async def _ready() -> bool:
    try:
        from .db import SessionFactory
        from sqlalchemy import text

        async with SessionFactory() as s:
            await s.execute(text("SELECT 1"))
        return True
    except Exception:
        return False


health.register("db", _ready)

app = create_app(
    service_name="social-service",
    version="0.1.0",
    description="Impact Feed posts, likes, comments and bookmarks.",
    health_checker=health,
    on_startup=[init_db],
    log_level="INFO",
)

app.include_router(router, prefix="/api/v1")
