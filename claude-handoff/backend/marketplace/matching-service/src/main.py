from shared.utils.app_factory import create_app
from .api import router
app = create_app("matching-service", "0.1.0",
    "AI-powered talent-opportunity matching using PMS vectors, skills, and SDG alignment.")
app.include_router(router, prefix="/api/v1")
