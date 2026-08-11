"""Chat service FastAPI application."""
from shared.utils.app_factory import create_app
from .api import router

app = create_app(
    "chat-service",
    "0.1.0",
    "Conversational assistant with real persistence and optional cloud LLM.",
)
app.include_router(router)
