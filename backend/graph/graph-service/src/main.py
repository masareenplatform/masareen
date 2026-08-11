from shared.utils.app_factory import create_app
from .api import router
app = create_app("graph-service", "0.1.0",
    "Neo4j knowledge graph: person-org-task-sdg-skill relationship traversal and intelligence.")
app.include_router(router, prefix="/api/v1")
