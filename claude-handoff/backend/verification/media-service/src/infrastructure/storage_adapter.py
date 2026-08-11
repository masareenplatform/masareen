"""Storage adapter abstraction for media asset binaries.

Implements abstract interface for object storage backends (MinIO, S3, etc.).
Never stores binary files inside PostgreSQL.
"""
from abc import ABC, abstractmethod
from typing import Dict, Optional, Any
from shared.exceptions import ValidationException


class StorageAdapter(ABC):
    """Abstraction layer for object storage services."""
    
    @abstractmethod
    async def upload(self, bucket: str, key: str, data: bytes, 
                     content_type: str = "application/octet-stream",
                     metadata: Optional[Dict[str, str]] = None) -> str:
        """Upload data to storage and return the storage URI.
        
        Args:
            bucket: Storage bucket name
            key: Unique key for the object
            data: Binary data to store
            content_type: MIME type of the data
            metadata: Optional metadata to store with the object
            
        Returns:
            Storage URI/URL for accessing the uploaded object
        """
        pass

    @abstractmethod
    async def download(self, bucket: str, key: str) -> bytes:
        """Download data from storage.
        
        Args:
            bucket: Storage bucket name
            key: Unique key for the object
            
        Returns:
            Binary data from storage
        """
        pass

    @abstractmethod
    async def delete(self, bucket: str, key: str) -> None:
        """Delete object from storage.
        
        Args:
            bucket: Storage bucket name
            key: Unique key for the object to delete
        """
        pass

    @abstractmethod
    async def exists(self, bucket: str, key: str) -> bool:
        """Check if object exists in storage.
        
        Args:
            bucket: Storage bucket name
            key: Unique key for the object
            
        Returns:
            True if object exists, False otherwise
        """
        pass

    @abstractmethod
    async def generate_presigned_url(self, bucket: str, key: str, 
                                     expires_seconds: int = 3600) -> str:
        """Generate a presigned URL for temporary access to object.
        
        Args:
            bucket: Storage bucket name
            key: Unique key for the object
            expires_seconds: URL validity duration in seconds
            
        Returns:
            Presigned URL string
        """
        pass


class MinIOAdapter(StorageAdapter):
    """MinIO object storage implementation."""
    
    def __init__(self, endpoint: str, access_key: str, secret_key: str,
                 secure: bool = True, bucket: str = "media-assets"):
        self._endpoint = endpoint
        self._access_key = access_key
        self._secret_key = secret_key
        self._secure = secure
        self._bucket = bucket
        self._client = None

    async def _get_client(self):
        """Get or create MinIO client."""
        if self._client is None:
            from minio import Minio
            self._client = Minio(
                self._endpoint,
                access_key=self._access_key,
                secret_key=self._secret_key,
                secure=self._secure,
            )
            # Ensure bucket exists
            found = await self._client.bucket_exists(self._bucket)
            if not found:
                await self._client.make_bucket(self._bucket)
        return self._client

    async def upload(self, bucket: str, key: str, data: bytes,
                     content_type: str = "application/octet-stream",
                     metadata: Optional[Dict[str, str]] = None) -> str:
        if not bucket:
            raise ValidationException("bucket is required.")
        if not key:
            raise ValidationException("key is required.")
        if not data:
            raise ValidationException("data is required.")

        client = await self._get_client()
        
        # Ensure bucket exists
        found = await client.bucket_exists(bucket)
        if not found:
            await client.make_bucket(bucket)

        # Upload with metadata
        put_args = client.put_object(
            bucket,
            key,
            data,
            length=len(data),
            content_type=content_type,
        )

        # Set metadata if provided
        if metadata:
            await client.set_object_tags(bucket, key, metadata)

        return f"minio://{bucket}/{key}"

    async def download(self, bucket: str, key: str) -> bytes:
        if not bucket:
            raise ValidationException("bucket is required.")
        if not key:
            raise ValidationException("key is required.")

        client = await self._get_client()
        data_stream = client.get_object(bucket, key)
        return data_stream.read()

    async def delete(self, bucket: str, key: str) -> None:
        if not bucket:
            raise ValidationException("bucket is required.")
        if not key:
            raise ValidationException("key is required.")

        client = await self._get_client()
        await client.remove_object(bucket, key)

    async def exists(self, bucket: str, key: str) -> bool:
        if not bucket:
            raise ValidationException("bucket is required.")
        if not key:
            raise ValidationException("key is required.")

        client = await self._get_client()
        return await client.stat_object(bucket, key)

    async def generate_presigned_url(self, bucket: str, key: str,
                                     expires_seconds: int = 3600) -> str:
        if not bucket:
            raise ValidationException("bucket is required.")
        if not key:
            raise ValidationException("key is required.")

        client = await self._get_client()
        return client.presigned_get_object(bucket, key, expires=expires_seconds)
