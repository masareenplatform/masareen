from shared.utils.app_factory import create_app
from .api import router
app = create_app("program-service", "0.1.0", "Program lifecycle, enrollment, milestones.")
app.include_router(router, prefix="/api/v1")
