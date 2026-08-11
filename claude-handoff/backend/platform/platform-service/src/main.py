"""Platform admin service — brokerage fee config + revenue/profit summary.

Entrypoint. Mounts the platform admin API under ``/api/v1/platform`` so the
gateway (which routes ``/api/v1/platform`` → this service) forwards correctly.
"""
from shared.utils.app_factory import create_app
from .api import router

app = create_app(
    "platform-service",
    "0.1.0",
    "Platform brokerage fee config + auditable revenue/profit ledger.",
)
app.include_router(router, prefix="/api/v1/platform")
