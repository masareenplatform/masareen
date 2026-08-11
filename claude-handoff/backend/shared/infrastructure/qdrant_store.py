"""Qdrant implementation of the VectorStore."""
from .vector_store import VectorStore
from qdrant_client import QdrantClient
from qdrant_client.http.models import PointStruct, VectorParams, Distance
from typing import List, Dict, Any, Optional
from shared.utils.logging import get_logger

log = get_logger(__name__)

class QdrantStore(VectorStore):
    """Qdrant-backed vector store for high-dimensional semantic search."""

    def __init__(self, host: str = "localhost", port: int = 6333, api_key: Optional[str] = None):
        self.client = QdrantClient(host=host, port=port, api_key=api_key)

    async def create_collection(self, collection_name: str, vector_size: int = 1536):
        """Initialize a collection if it doesn't exist."""
        try:
            self.client.create_collection(
                collection_name=collection_name,
                vectors_config=VectorParams(size=vector_size, distance=Distance.COSINE),
            )
            log.info(f"Created Qdrant collection: {collection_name}")
        except Exception:
            log.debug(f"Collection {collection_name} already exists.")

    async def upsert_vector(self, collection: str, vector_id: str, vector: List[float], payload: Dict[str, Any]) -> None:
        self.client.upsert(
            collection_name=collection,
            points=[PointStruct(id=vector_id, vector=vector, payload=payload)]
        )

    async def search(self, collection: str, query_vector: List[float], limit: int = 10) -> List[Dict[str, Any]]:
        results = self.client.search(
            collection_name=collection,
            query_vector=query_vector,
            limit=limit
        )
        return [
            {"id": hit.id, "score": hit.score, "payload": hit.payload}
            for hit in results
        ]

    async def delete_vector(self, collection: str, vector_id: str) -> None:
        self.client.delete(
            collection_name=collection,
            points_selector=[vector_id]
        )

    async def get_vector(self, collection: str, vector_id: str) -> Optional[Dict[str, Any]]:
        res = self.client.retrieve(collection_name=collection, ids=[vector_id])
        return res[0] if res else None
