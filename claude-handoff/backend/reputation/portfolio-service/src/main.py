from shared.utils.app_factory import create_app
from .api import router
app = create_app("portfolio-service", "0.1.0",
    "Individual impact portfolios, digital asset registry, Impact Passport.")
app.include_router(router, prefix="/api/v1")
