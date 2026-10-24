"""
FastAPI application factory.
Each service calls create_app() to get a pre-configured FastAPI instance
with CORS, logging middleware, health endpoint, and Prometheus metrics.
"""
from __future__ import annotations
from contextlib import asynccontextmanager
from typing import AsyncGenerator, Callable, List, Optional
import logging
import os

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import uuid

from .logging import bind_request_context, clear_request_context, configure_logging
from .health import HealthChecker
from ..exceptions import DomainException


def create_app(
    service_name: str,
    version: str = "0.1.0",
    description: str = "",
    health_checker: Optional[HealthChecker] = None,
    on_startup: Optional[List[Callable]] = None,
    on_shutdown: Optional[List[Callable]] = None,
    allowed_origins: List[str] | None = None,
    log_level: str = "INFO",
) -> FastAPI:
    configure_logging(service_name, log_level)

    @asynccontextmanager
    async def lifespan(app: FastAPI) -> AsyncGenerator:
        # Startup
        for fn in (on_startup or []):
            try:
                await fn()
            except Exception:
                # The combined backend hosts independent bounded contexts in
                # one process.  A non-critical integration used by one
                # service (for example a local seed database or a broker)
                # must not make every API route unavailable.  Standalone
                # services retain their existing fail-fast startup semantics.
                if os.getenv("MASAREN_COMBINED_BACKEND") != "1":
                    raise
                logging.getLogger(service_name).exception(
                    "Startup hook failed; continuing in combined mode",
                    extra={"startup_hook": getattr(fn, "__name__", repr(fn))},
                )
        yield
        # Shutdown
        for fn in (on_shutdown or []):
            await fn()

    app = FastAPI(
        title=service_name,
        description=description,
        version=version,
        lifespan=lifespan,
        docs_url="/docs",
        redoc_url="/redoc",
        openapi_url="/openapi.json",
    )

    # CORS
    app.add_middleware(
        CORSMiddleware,
        allow_origins=allowed_origins or ["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Request context middleware (trace_id injection)
    @app.middleware("http")
    async def request_context_middleware(request: Request, call_next):
        trace_id = request.headers.get("X-Trace-Id", str(uuid.uuid4()))
        bind_request_context(trace_id=trace_id)
        response = await call_next(request)
        response.headers["X-Trace-Id"] = trace_id
        clear_request_context()
        return response

    # Domain exception handler
    @app.exception_handler(DomainException)
    async def domain_exception_handler(request: Request, exc: DomainException):
        status_map = {
            "NOT_FOUND": 404,
            "VALIDATION_ERROR": 422,
            "UNAUTHORIZED": 401,
            "CONFLICT": 409,
        }
        return JSONResponse(
            status_code=status_map.get(exc.code, 400),
            content={"success": False, "error": exc.code, "message": exc.message},
        )

    # Catch-all exception handler, ensures ALL errors return JSON
    @app.exception_handler(Exception)
    async def global_exception_handler(request: Request, exc: Exception):
        import logging
        logging.getLogger(service_name).exception(
            "Unhandled exception",
            extra={"path": request.url.path, "method": request.method},
        )
        return JSONResponse(
            status_code=500,
            content={
                "success": False,
                "error": "INTERNAL_ERROR",
                "message": "An unexpected error occurred. Please try again.",
            },
        )

    # Health endpoint
    @app.get("/health", tags=["Infrastructure"])
    async def health():
        if health_checker:
            report = await health_checker.run()
            return report.to_dict()
        return {"status": "healthy", "service": service_name, "version": version}

    return app
