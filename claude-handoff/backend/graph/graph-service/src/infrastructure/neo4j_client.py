"""
Neo4j infrastructure for the graph-service.

Provides a singleton async driver and a small repository that executes the
real Cypher queries defined in ``queries/person_queries.py``. When Neo4j is
unreachable the repository raises (it never returns fabricated/empty data as if
the graph were populated).
"""
from __future__ import annotations
from typing import Any, Dict, List, Optional

from shared.utils.logging import get_logger

log = get_logger(__name__)

try:
    from neo4j import AsyncGraphDatabase, AsyncDriver
except Exception:  # pragma: no cover - driver optional at import time
    AsyncGraphDatabase = None
    AsyncDriver = None
    log.warning("neo4j_driver_unavailable",
                detail="neo4j package not installed; graph endpoints will error honestly")


class Neo4jClient:
    _driver: Optional["AsyncDriver"] = None

    @classmethod
    def get_driver(cls, uri: str, user: str, password: str) -> Optional["AsyncDriver"]:
        if AsyncGraphDatabase is None:
            return None
        if cls._driver is None:
            cls._driver = AsyncGraphDatabase.driver(uri, auth=(user, password))
        return cls._driver

    @classmethod
    async def close(cls) -> None:
        if cls._driver is not None:
            await cls._driver.close()
            cls._driver = None


class GraphRepository:
    def __init__(self, driver: Optional["AsyncDriver"]) -> None:
        self._driver = driver

    async def upsert_person(self, person_id: str, name: str, email: str,
                            pms: float, created_at: str) -> None:
        if self._driver is None:
            raise RuntimeError("neo4j_unavailable")
        query = """
        MERGE (p:Person {id: $id})
        SET p.name = $name, p.email = $email, p.pms = $pms, p.created_at = $created_at
        RETURN p
        """

        async def _tx(tx):
            await tx.run(query, id=person_id, name=name, email=email,
                         pms=pms, created_at=created_at)

        async with self._driver.session() as session:
            await session.execute_write(_tx)

    async def upsert_node(self, node_id: str, label: str,
                          properties: Dict[str, Any]) -> None:
        if self._driver is None:
            raise RuntimeError("neo4j_unavailable")
        query = f"MERGE (n:{label} {{id: $id}}) SET n += $props RETURN n"

        async def _tx(tx):
            await tx.run(query, id=node_id, props=properties)

        async with self._driver.session() as session:
            await session.execute_write(_tx)

    async def create_relationship(self, from_id: str, from_label: str,
                                  to_id: str, to_label: str,
                                  relationship_type: str,
                                  properties: Dict[str, Any]) -> None:
        if self._driver is None:
            raise RuntimeError("neo4j_unavailable")
        # Bind `r` in the MERGE so the relationship properties can be set.
        query = (
            f"MATCH (a:{from_label} {{id: $from_id}}) "
            f"MATCH (b:{to_label} {{id: $to_id}}) "
            f"MERGE (a)-[r:{relationship_type}]->(b) "
            f"SET r += $props "
            f"RETURN r"
        )

        async def _tx(tx):
            await tx.run(query, from_id=from_id, to_id=to_id, props=properties)

        async with self._driver.session() as session:
            await session.execute_write(_tx)

    async def run_read_query(self, query: str,
                             parameters: Dict[str, Any]) -> List[Dict[str, Any]]:
        if self._driver is None:
            raise RuntimeError("neo4j_unavailable")

        async def _tx(tx):
            result = await tx.run(query, parameters)
            return await result.data()

        async with self._driver.session() as session:
            return await session.execute_read(_tx)

    async def get_impact_network(self, person_id: str) -> Dict[str, Any]:
        from ..queries.person_queries import GET_PERSON_IMPACT_NETWORK
        if self._driver is None:
            raise RuntimeError("neo4j_unavailable")

        async def _tx(tx):
            result = await tx.run(GET_PERSON_IMPACT_NETWORK, person_id=person_id)
            return await result.data()

        async with self._driver.session() as session:
            result = await session.execute_read(_tx)
        row = result[0] if result else {}
        return {
            "person_id": person_id,
            "tasks": [dict(t) for t in (row.get("tasks") or [])],
            "programs": [dict(p) for p in (row.get("programs") or [])],
            "sdgs": [dict(s) for s in (row.get("sdgs") or [])],
            "skills": [dict(s) for s in (row.get("skills") or [])],
            "impact_assets": [dict(a) for a in (row.get("impact_assets") or [])],
        }

    async def talent_match(self, person_id: str, limit: int) -> List[Dict[str, Any]]:
        from ..queries.person_queries import MATCH_PERSON_TO_OPPORTUNITIES
        if self._driver is None:
            raise RuntimeError("neo4j_unavailable")

        async def _tx(tx):
            result = await tx.run(MATCH_PERSON_TO_OPPORTUNITIES,
                                  person_id=person_id, limit=limit)
            return await result.data()

        async with self._driver.session() as session:
            result = await session.execute_read(_tx)
        return [dict(r) for r in result]

    async def node_count(self) -> int:
        if self._driver is None:
            raise RuntimeError("neo4j_unavailable")

        async def _tx(tx):
            result = await tx.run("MATCH (n) RETURN count(n) AS c")
            return await result.data()

        async with self._driver.session() as session:
            result = await session.execute_read(_tx)
        return result[0]["c"] if result else 0

    async def relationship_count(self) -> int:
        if self._driver is None:
            raise RuntimeError("neo4j_unavailable")

        async def _tx(tx):
            result = await tx.run("MATCH ()-[r]->() RETURN count(r) AS c")
            return await result.data()

        async with self._driver.session() as session:
            result = await session.execute_read(_tx)
        return result[0]["c"] if result else 0
