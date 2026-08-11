from shared.utils.app_factory import create_app
from .api import router
app = create_app("billing-service", "0.1.0", "Usage tracking and invoice generation.")
app.include_router(router, prefix="/api/v1")
