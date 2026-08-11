from shared.utils.app_factory import create_app
from .api import router
app = create_app("task-service", "0.1.0",
    "Task assignment, FSM state machine, completion and verification pipeline.")
app.include_router(router, prefix="/api/v1")
