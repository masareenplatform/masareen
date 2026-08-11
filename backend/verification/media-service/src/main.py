import sys, os; sys.path.insert(0, os.path.join(os.path.dirname(__file__), "../../.."))
from shared.utils.app_factory import create_app
from .api import router
app = create_app("media-service", "0.1.0", "Media upload slots, presigned URLs, CDN delivery, processing pipeline.")
app.include_router(router, prefix="/api/v1")
