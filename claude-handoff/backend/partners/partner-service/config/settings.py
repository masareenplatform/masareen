"""Runtime settings for the partner / collaboration-hosting service."""
from __future__ import annotations
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="", env_file=".env", extra="ignore")

    service_name: str = "partner-service"
    environment: str = "development"
    database_url: str = "postgresql+asyncpg://masaren:masaren_password@localhost:5432/masaren"
    redis_url: str = "redis://localhost:6379"
    jwt_secret: str = "change-me-in-production"
    jwt_algorithm: str = "HS256"
    kafka_bootstrap_servers: str = "localhost:9092"
    log_level: str = "INFO"


settings = Settings()
