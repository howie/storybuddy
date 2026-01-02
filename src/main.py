"""FastAPI application entry point for StoryBuddy."""

import json
import logging
import sys
import time
from collections.abc import AsyncGenerator, Awaitable, Callable
from contextlib import asynccontextmanager
from typing import Any
from uuid import uuid4

from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from src.api import parents, qa, stories, voice
from src.config import get_settings
from src.db.init import init_database

# Configure structured logging
settings = get_settings()


class JSONFormatter(logging.Formatter):
    """JSON log formatter for structured logging."""

    def format(self, record: logging.LogRecord) -> str:
        """Format log record as JSON."""
        log_data: dict[str, Any] = {
            "timestamp": self.formatTime(record, self.datefmt),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }

        # Add extra fields if present
        if hasattr(record, "request_id"):
            log_data["request_id"] = record.request_id
        if hasattr(record, "method"):
            log_data["method"] = record.method
        if hasattr(record, "path"):
            log_data["path"] = record.path
        if hasattr(record, "status_code"):
            log_data["status_code"] = record.status_code
        if hasattr(record, "duration_ms"):
            log_data["duration_ms"] = record.duration_ms

        if record.exc_info:
            log_data["exception"] = self.formatException(record.exc_info)

        return json.dumps(log_data)


def setup_logging() -> logging.Logger:
    """Configure application logging."""
    logger = logging.getLogger("storybuddy")
    logger.setLevel(getattr(logging, settings.log_level))

    # Remove existing handlers
    logger.handlers.clear()

    # Create handler
    handler = logging.StreamHandler(sys.stdout)
    handler.setLevel(getattr(logging, settings.log_level))

    # Set formatter based on config
    if settings.log_format == "json":
        handler.setFormatter(JSONFormatter())
    else:
        handler.setFormatter(
            logging.Formatter(
                "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
            )
        )

    logger.addHandler(handler)
    return logger


logger = setup_logging()


@asynccontextmanager
async def lifespan(_app: FastAPI) -> AsyncGenerator[None, None]:
    """Application lifespan events."""
    # Startup
    logger.info("Starting StoryBuddy API...")
    settings.ensure_directories()
    await init_database()
    logger.info("Database initialized")
    logger.info(f"API running on {settings.api_host}:{settings.api_port}")

    yield

    # Shutdown
    logger.info("Shutting down StoryBuddy API...")


app = FastAPI(
    title="StoryBuddy API",
    description="AI-powered storytelling app with parent voice cloning",
    version="0.1.0",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def request_logging_middleware(
    request: Request, call_next: Callable[[Request], Awaitable[Response]]
) -> Response:
    """Log all requests with timing information."""
    request_id = str(uuid4())
    request.state.request_id = request_id

    start_time = time.perf_counter()

    # Log request
    logger.info(
        "Request started",
        extra={
            "request_id": request_id,
            "method": request.method,
            "path": request.url.path,
        },
    )

    try:
        response = await call_next(request)
        duration_ms = (time.perf_counter() - start_time) * 1000

        # Log response
        logger.info(
            "Request completed",
            extra={
                "request_id": request_id,
                "method": request.method,
                "path": request.url.path,
                "status_code": response.status_code,
                "duration_ms": round(duration_ms, 2),
            },
        )

        response.headers["X-Request-ID"] = request_id
        return response

    except Exception as e:
        duration_ms = (time.perf_counter() - start_time) * 1000
        logger.error(
            f"Request failed: {e!s}",
            extra={
                "request_id": request_id,
                "method": request.method,
                "path": request.url.path,
                "duration_ms": round(duration_ms, 2),
            },
            exc_info=True,
        )
        raise


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    """Global exception handler for unhandled errors."""
    request_id = getattr(request.state, "request_id", "unknown")
    logger.error(
        f"Unhandled exception: {exc!s}",
        extra={"request_id": request_id},
        exc_info=True,
    )

    return JSONResponse(
        status_code=500,
        content={
            "detail": "Internal server error",
            "request_id": request_id,
        },
    )


@app.get("/health")
async def health_check() -> dict[str, str]:
    """Health check endpoint."""
    return {"status": "healthy", "version": "0.1.0"}


@app.get("/")
async def root() -> dict[str, str]:
    """Root endpoint."""
    return {
        "name": "StoryBuddy API",
        "version": "0.1.0",
        "docs": "/docs",
    }


# Include routers
app.include_router(parents.router, prefix="/api/v1")
app.include_router(voice.router, prefix="/api/v1")
app.include_router(stories.router, prefix="/api/v1")
app.include_router(qa.router, prefix="/api/v1")
# app.include_router(questions.router, prefix="/api/v1", tags=["Questions"])


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "src.main:app",
        host=settings.api_host,
        port=settings.api_port,
        reload=settings.debug,
    )
