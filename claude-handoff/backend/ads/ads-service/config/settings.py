"""Service configuration (12-Factor App)."""
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    service_name: str = "masaren-ads-service"
    debug: bool = False
    database_url: str = "postgresql+asyncpg://masaren:masaren_password@localhost:5432/masaren"
    kafka_bootstrap_servers: str = "localhost:9092"
    redis_url: str = "redis://localhost:6379"
    neo4j_url: str = "bolt://localhost:7687"
    neo4j_user: str = "neo4j"
    neo4j_password: str = "masaren_dev"
    jwt_secret: str = "change-me-in-production"
    jwt_algorithm: str = "HS256"
    # Cost per ad event, charged in MASAREN Coin (MRC) against the campaign budget.
    ad_impression_cost_mrc: float = 1.0
    ad_click_cost_mrc: float = 3.0

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


settings = Settings()
