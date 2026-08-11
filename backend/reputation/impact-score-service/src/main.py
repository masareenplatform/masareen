from shared.utils.app_factory import create_app
from .api import router
app = create_app("impact-score-service", "0.1.0",
    "Proof of Mission Score (PMS) engine — multidimensional individual reputation vector.")
app.include_router(router, prefix="/api/v1")
