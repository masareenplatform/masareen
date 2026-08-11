"""Service configuration (12-Factor App)."""
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    service_name: str = "authentication-service"
    debug: bool = False
    database_url: str = "postgresql+asyncpg://masaren:masaren_dev@localhost:5432/masaren"
    kafka_bootstrap_servers: str = "localhost:9092"
    redis_url: str = "redis://localhost:6379"
    jwt_secret: str = "change-me-in-production"
    jwt_algorithm: str = "HS256"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


settings = Settings()
