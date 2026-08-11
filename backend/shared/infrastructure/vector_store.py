"""Vector database abstraction for semantic search and matching."""
from abc import ABC, abstractmethod
from typing import List, Dict, Any, Optional

class VectorStore(ABC):
    """Interface for a vector database (Qdrant, Milvus, Pinecone, etc.)."""

    @abstractmethod
    async def upsert_vector(self, collection: str, vector_id: str, vector: List[float], payload: Dict[str, Any]) -> None:
        """Insert or update a vector with its associated payload."""
        pass

    @abstractmethod
    async def search(self, collection: str, query_vector: List[float], limit: int = 10) -> List[Dict[str, Any]]:
        """Search for the nearest neighbors of a query vector."""
        pass

    @abstractmethod
    async def delete_vector(self, collection: str, vector_id: str) -> None:
        """Remove a vector from the store."""
        pass

    @abstractmethod
    async def get_vector(self, collection: str, vector_id: str) -> Optional[Dict[str, Any]]:
        """Retrieve a specific vector and its payload."""
        pass
