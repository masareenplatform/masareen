"""Lazy config loader — avoids circular imports between shared modules."""
import os


def get_database_url() -> str:
    return os.environ.get(
        "DATABASE_URL",
        "postgresql+asyncpg://masaren_user:masaren_dev@localhost:5432/masaren_impact"
    )


def get_kafka_bootstrap() -> str:
    return os.environ.get("KAFKA_BOOTSTRAP_SERVERS", "kafka:9092")


def get_redis_url() -> str:
    return os.environ.get("REDIS_URL", "redis://masaren-redis:6379")


def get_neo4j_url() -> str:
    return os.environ.get("NEO4J_URI", "bolt://masaren-neo4j:7687")


def get_neo4j_auth() -> tuple[str, str]:
    return (
        os.environ.get("NEO4J_USER", "neo4j"),
        os.environ.get("NEO4J_PASSWORD", "masaren_dev"),
    )


# ── Cloud AI (Hybrid Architecture — 0GB VRAM on-prem server) ─────────────────
def get_ai_provider() -> str:
    """Which cloud LLM provider to use: openai | google | bedrock"""
    return os.environ.get("AI_PROVIDER", "google")


def get_cloud_api_key() -> str:
    return os.environ.get("CLOUD_API_KEY", "")


def get_openai_api_key() -> str:
    return os.environ.get("OPENAI_API_KEY", get_cloud_api_key())


def get_google_api_key() -> str:
    return os.environ.get("GOOGLE_API_KEY", get_cloud_api_key())
