from shared.utils.app_factory import create_app
from .api import router

app = create_app("partner-service", "0.1.0",
                 "Collaboration onboarding: companies/startups hosting services on MASAREEN infrastructure.")
app.include_router(router, prefix="/api/v1")
