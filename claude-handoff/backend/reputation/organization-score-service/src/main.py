from shared.utils.app_factory import create_app
from .api import router
app = create_app("organization-score-service", "0.1.0",
    "Organisational Impact Index (OII) — institutional reputation profile.")
app.include_router(router, prefix="/api/v1")
