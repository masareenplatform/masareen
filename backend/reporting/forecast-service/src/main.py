from shared.utils.app_factory import create_app
from .api import router

app = create_app(
    "forecast-service",
    "0.1.0",
    "Deterministic impact forecasting from real historical trends.",
)
app.include_router(router, prefix="/api/v1")
