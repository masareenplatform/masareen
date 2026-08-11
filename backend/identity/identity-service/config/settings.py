"""Service configuration (12-Factor App)."""
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    service_name: str = "masaren-service"
    debug: bool = False
    database_url: str = "postgresql+asyncpg://masaren:masaren_dev@localhost:5432/masaren"
    kafka_bootstrap_servers: str = "localhost:9092"
    redis_url: str = "redis://localhost:6379"
    neo4j_url: str = "bolt://localhost:7687"
    neo4j_user: str = "neo4j"
    neo4j_password: str = "masaren_dev"
    jwt_secret: str = "change-me-in-production"
    jwt_algorithm: str = "HS256"
    # Alpha mode: when true, newly registered accounts are auto-verified and
    # activated so users can sign in immediately without an email verification
    # step. Set AUTO_VERIFY_ON_REGISTER=true in alpha/demo environments only.
    auto_verify_on_register: bool = False

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


settings = Settings()
