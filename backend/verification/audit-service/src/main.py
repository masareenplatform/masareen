import sys, os; sys.path.insert(0, os.path.join(os.path.dirname(__file__), "../../.."))
from shared.utils.app_factory import create_app
from .api import router
app = create_app("audit-service", "0.1.0",
    "Immutable audit trail, append-only log of all domain events for compliance and debugging.")
app.include_router(router, prefix="/api/v1")
