from shared.utils.app_factory import create_app
from .api import router

app = create_app("coin-service", "0.1.0",
                 "MASAREEN Coin (MRC) wallet, peer transfers and EGP exchange.")
app.include_router(router, prefix="/api/v1/coin")
