"""Chat service configuration."""
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    service_name: str = "chat-service"
    database_url: str = "postgresql+asyncpg://masaren_user:masaren_dev@localhost:5432/masaren_impact"
    google_api_key: str = ""
    model: str = "gemma-4-31b-it"

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


settings = Settings()
