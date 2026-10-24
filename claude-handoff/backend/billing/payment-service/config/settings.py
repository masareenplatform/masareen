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

    # Paymob (Egypt), card iframe + Vodafone Cash wallet
    paymob_api_key: str = ""
    paymob_hmac_secret: str = ""
    paymob_wallet_integration_id: str = ""
    paymob_vodafone_integration_id: str = ""
    paymob_iframe_id: str = ""
    paymob_currency: str = "EGP"
    paymob_api_base: str = "https://accept.paymob.com"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


settings = Settings()
