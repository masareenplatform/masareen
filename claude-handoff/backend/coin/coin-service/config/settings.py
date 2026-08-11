"""Service configuration (12-Factor App)."""
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    service_name: str = "masaren-coin-service"
    debug: bool = False
    database_url: str = "postgresql+asyncpg://masaren:masaren_password@localhost:5432/masaren"
    kafka_bootstrap_servers: str = "localhost:9092"
    redis_url: str = "redis://localhost:6379"
    neo4j_url: str = "bolt://localhost:7687"
    neo4j_user: str = "neo4j"
    neo4j_password: str = "masaren_dev"
    jwt_secret: str = "change-me-in-production"
    jwt_algorithm: str = "HS256"
    # Default in-app coin exchange rate: 1 EGP = N MRC (MASAREN Coin).
    default_mrc_per_egp: float = 10.0

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


settings = Settings()
