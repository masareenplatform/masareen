"""
Submission service settings.
"""
from pydantic import BaseSettings
from typing import Optional


class SubmissionSettings(BaseSettings):
    service_name: str = "submission-service"
    service_version: str = "0.1.0"
    database_url: str = "postgresql://postgres:password@localhost:5432/masaren"
    kafka_bootstrap_servers: str = "localhost:9092"
    redis_url: str = "redis://localhost:6379"
    kafka_submission_topic: str = "masaren.verification.submission.created"
    max_submission_size_mb: int = 100
    max_evidence_items_per_submission: int = 10
    min_approval_score: float = 0.7
    geofence_required: bool = True

    class Config:
        env_prefix = "SUBMISSION_"
        env_file = ".env"
        case_sensitive = False
