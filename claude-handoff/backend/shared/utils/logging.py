"""
Structured JSON logging for all MASAREN services.
Every log entry includes: service, trace_id, user_id, event_type, and message.
"""
import logging
import sys
import structlog
from typing import Optional


def configure_logging(service_name: str, log_level: str = "INFO") -> None:
    """Call once at service startup, before any log.info() calls."""

    structlog.configure(
        processors=[
            structlog.contextvars.merge_contextvars,
            structlog.processors.add_log_level,
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.JSONRenderer(),
        ],
        wrapper_class=structlog.make_filtering_bound_logger(
            logging.getLevelName(log_level)
        ),
        context_class=dict,
        logger_factory=structlog.PrintLoggerFactory(sys.stdout),
    )

    # Bind service name to all logs in this process
    structlog.contextvars.bind_contextvars(service=service_name)


def get_logger(name: str):
    return structlog.get_logger(name)


def bind_request_context(
    trace_id: Optional[str] = None,
    user_id: Optional[str] = None,
    correlation_id: Optional[str] = None,
) -> None:
    """Bind per-request context, call from middleware."""
    ctx = {}
    if trace_id:
        ctx["trace_id"] = trace_id
    if user_id:
        ctx["user_id"] = user_id
    if correlation_id:
        ctx["correlation_id"] = correlation_id
    if ctx:
        structlog.contextvars.bind_contextvars(**ctx)


def clear_request_context() -> None:
    structlog.contextvars.clear_contextvars()
