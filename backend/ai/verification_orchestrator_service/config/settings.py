from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    service_name: str = "verification-orchestrator-service"
    debug: bool = False
    database_url: str = "postgresql+asyncpg://masaren:masaren_dev@localhost:5432/masaren"
    kafka_bootstrap_servers: str = "localhost:9092"
    redis_url: str = "redis://localhost:6379"
    neo4j_url: str = "bolt://localhost:7687"
    neo4j_user: str = "neo4j"
    neo4j_password: str = "masaren_dev"
    jwt_secret: str = "change-me-in-production"
    jwt_algorithm: str = "HS256"
    bff_url: str = "http://localhost:8000/api"
    # Audit-service base URL (owns the human-review queue). Incl. /audit prefix.
    audit_service_url: str = "http://localhost:8012/audit"
    # Confidence below which a verdict is routed to human review.
    hitl_confidence_threshold: float = 0.75

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        extra = "ignore"

settings = Settings()
