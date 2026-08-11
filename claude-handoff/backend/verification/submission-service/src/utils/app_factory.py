"""Re-export shared app factory for submission service."""
from shared.utils.app_factory import create_app as shared_create_app
from shared.utils.logging import get_logger

log = get_logger(__name__)


def create_app(service_name: str, version: str, description: str):
    """Create FastAPI app using shared factory with submission defaults."""
    app = shared_create_app(service_name, version, description)

    @app.on_event("startup")
    async def startup():
        log.info("Starting submission service")

    @app.on_event("shutdown")
    async def shutdown():
        log.info("Shutting down submission service")

    return app
