"""Real HTTP client for the graph-service knowledge graph.

Talks to the graph-service REST API (``POST /graph/query`` for Cypher and the
specialised GET endpoints). No embedded Neo4j driver here, matching-service is
a consumer of the graph bounded context, not its owner.
"""
from typing import Any, Dict, List

import httpx

from shared.utils.logging import get_logger

log = get_logger(__name__)


class GraphClient:
    def __init__(self, base_url: str, timeout: float = 10.0):
        # base_url includes the /graph prefix, e.g. http://graph-service:8011/graph
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout

    async def execute_query(self, query: str, params: Dict[str, Any]) -> List[Dict[str, Any]]:
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            resp = await client.post(
                f"{self.base_url}/query",
                json={"query": query, "parameters": params, "read_only": True},
            )
            resp.raise_for_status()
            return resp.json().get("data", []) or []

    async def get(self, endpoint: str, params: Dict[str, Any]) -> List[Dict[str, Any]]:
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            resp = await client.get(f"{self.base_url}{endpoint}", params=params)
            resp.raise_for_status()
            return resp.json().get("data", []) or []
