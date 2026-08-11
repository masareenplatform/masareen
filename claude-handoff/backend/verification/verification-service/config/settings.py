'''Configuration module for verification service.'''
from pydantic_settings import BaseSettings
import os
from typing import Optional


class Settings(BaseSettings):
    service_name: str = "verification-service"
    service_version: str = "0.1.0"
    debug: bool = False
    database_url: str = "postgresql+asyncpg://postgres:postgres@localhost:5432/masaren"
    kafka_bootstrap_servers: str = "localhost:9092"
    redis_url: str = "redis://localhost:6379"
    jwt_secret: str = "secret"
    jwt_algorithm: str = "HS256"
    ai_confidence_threshold: float = 0.80
    fraud_risk_threshold: int = 30

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = False


settings = Settings()
