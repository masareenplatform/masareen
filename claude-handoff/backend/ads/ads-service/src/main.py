from shared.utils.app_factory import create_app
from .api import router

app = create_app("ads-service", "0.1.0",
                 "MASAREN Ads manager: campaigns, creatives and coin-funded delivery.")
app.include_router(router, prefix="/api/v1/ads")
