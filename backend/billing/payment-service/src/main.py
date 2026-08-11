from shared.utils.app_factory import create_app
from .api import router
app = create_app("payment-service", "0.1.0", "Stripe payment gateway integration.")
app.include_router(router, prefix="/api/v1")
