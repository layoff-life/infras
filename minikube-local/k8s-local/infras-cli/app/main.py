"""Main FastAPI application for infras-cli."""

import sys
from pathlib import Path

# Add parent directory to Python path so we can import app module
# Resolve to absolute path first, then get parent (project root)
_project_root = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_project_root))

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse
from fastapi.openapi.utils import get_openapi
from app.api.routes import api_router
from app.config import settings
from app.utils.logging import configure_logging
import structlog

# Configure logging
configure_logging(settings.log_level, settings.log_format)
logger = structlog.get_logger(__name__)

# Create FastAPI app
app = FastAPI(
    title="Infras-CLI API",
    description="""
    Infrastructure ACL Management API for Kubernetes.

    This API provides endpoints for managing access controls on various infrastructure services:
    - MySQL: Database and user creation
    - PostgreSQL: Database and user creation
    - Redis: ACL user management
    - Kafka: SASL user and ACL management
    - Keycloak: Realm, user, and client management

    All operations integrate with Vault for secure credential storage.
    """,
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json"
)

# Include API routes
app.include_router(api_router, prefix="/api/v1")


# ============================================================================
# Exception Handlers
# ============================================================================

@app.exception_handler(ValueError)
async def value_error_handler(request: Request, exc: ValueError):
    """Handle ValueError exceptions (validation errors)."""
    logger.warning("Validation error", error=str(exc))
    return JSONResponse(
        status_code=400,
        content={
            "detail": str(exc),
            "type": "validation_error"
        }
    )


@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    """Handle HTTPException."""
    if exc.status_code >= 500:
        logger.error("HTTP exception", status_code=exc.status_code, detail=exc.detail)
    return JSONResponse(
        status_code=exc.status_code,
        content={"detail": exc.detail}
    )


@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception):
    """Handle all unhandled exceptions."""
    logger.error("Unhandled exception", error=str(exc), exc_info=True)
    return JSONResponse(
        status_code=500,
        content={
            "detail": "Internal server error",
            "type": "internal_error"
        }
    )


# ============================================================================
# Event Handlers
# ============================================================================

@app.on_event("startup")
async def startup_event():
    """Log application startup."""
    logger.info(
        "Starting Infras-CLI API",
        vault_addr=settings.vault_addr,
        log_level=settings.log_level
    )


@app.on_event("shutdown")
async def shutdown_event():
    """Log application shutdown."""
    logger.info("Shutting down Infras-CLI API")


# ============================================================================
# Root Endpoints
# ============================================================================

@app.get("/")
async def root():
    """Root endpoint with API information."""
    return {
        "name": "Infras-CLI API",
        "version": "1.0.0",
        "description": "Infrastructure ACL Management API",
        "docs": "/docs",
        "redoc": "/redoc",
        "openapi": "/openapi.json"
    }


# ============================================================================
# Custom OpenAPI Schema
# ============================================================================

def custom_openapi():
    """Generate custom OpenAPI schema with additional metadata."""
    if app.openapi_schema:
        return app.openapi_schema

    openapi_schema = get_openapi(
        title="Infras-CLI API",
        version="1.0.0",
        description="""
        ## Infrastructure ACL Management API

        This API provides endpoints for managing access controls on various infrastructure services in Kubernetes.

        ### Features

        * **ACL Management**: Create and verify ACLs for MySQL, PostgreSQL, Redis, Kafka, and Keycloak
        * **User Management**: Create Vault users and assign policies
        * **Vault Integration**: All credentials stored securely in Vault KV v2
        * **Kubernetes Integration**: Direct execution in pods using kubectl exec pattern

        ### Authentication

        This API uses Vault token authentication. Set the `VAULT_TOKEN` environment variable.

        ### Supported Infrastructure Types

        * `mysql` - MySQL database and user management
        * `postgres` - PostgreSQL database and user management
        * `redis` - Redis ACL user management
        * `kafka` - Kafka SASL user and ACL management
        * `keycloak` - Keycloak realm, user, and client management

        ### Response Format

        All endpoints return JSON responses with appropriate HTTP status codes:

        * `200 OK` - Successful GET/DELETE requests
        * `201 Created` - Successful POST requests creating resources
        * `400 Bad Request` - Invalid input parameters
        * `404 Not Found` - Resource not found
        * `500 Internal Server Error` - Server-side errors
        """,
        routes=app.routes,
    )

    # Add tags metadata
    openapi_schema["tags"] = [
        {
            "name": "Health",
            "description": "Health check endpoints for liveness and readiness probes"
        },
        {
            "name": "ACL",
            "description": "ACL management endpoints for creating and verifying access controls"
        },
        {
            "name": "Users",
            "description": "User management endpoints for Vault userpass users"
        }
    ]

    app.openapi_schema = openapi_schema
    return app.openapi_schema


app.openapi = custom_openapi


# ============================================================================
# Development Server Entry Point
# ============================================================================

if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level=settings.log_level.lower()
    )
