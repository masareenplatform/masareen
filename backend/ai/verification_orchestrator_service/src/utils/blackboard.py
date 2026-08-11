"""Shared blackboard for the CrewAI verification crew.

Stores the crew's real intermediate reasoning/audit entries. The store is an
append-only log file whose path is configurable via ``BLACKBOARD_LOG_PATH`` so it
can be mounted on a persistent volume in production. Entries are real crew output
(no synthetic data).
"""
import datetime
import os

from shared.utils.logging import get_logger

logger = get_logger(__name__)


class Blackboard:
    """A shared file-based blackboard for CrewAI agents to log steps and findings."""

    def __init__(self, log_file: str | None = None):
        # Configurable path (mount a volume in prod); defaults to service-local file.
        self.log_path = log_file or os.getenv("BLACKBOARD_LOG_PATH", "blackboard.log")

    def log(self, agent_name: str, action: str, content: str):
        """Append a timestamped entry to the blackboard."""
        timestamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
        entry = f"[{timestamp}] [{agent_name}] {action}: {content}\n"
        with open(self.log_path, "a", encoding="utf-8") as f:
            f.write(entry)
        logger.debug(f"BLACKBOARD: {entry.strip()}")

    def get_latest(self) -> str:
        """Return the full content of the blackboard (empty string if none)."""
        if not os.path.exists(self.log_path):
            return ""
        with open(self.log_path, "r", encoding="utf-8") as f:
            return f.read()

    def clear(self):
        """Clear the blackboard."""
        if os.path.exists(self.log_path):
            os.remove(self.log_path)


blackboard = Blackboard()
