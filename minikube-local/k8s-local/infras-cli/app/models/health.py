"""Pydantic models for health check operations."""

from pydantic import BaseModel, Field


class HealthResponse(BaseModel):
    """Response model for health checks.

    Attributes:
        status: Overall health status ("healthy" or "unhealthy")
        vault_connected: Whether Vault is accessible
        kubernetes_connected: Whether Kubernetes API is accessible
    """
    status: str = Field(..., description="Overall health status: healthy or unhealthy")
    vault_connected: bool = Field(..., description="Whether Vault is accessible")
    kubernetes_connected: bool = Field(..., description="Whether Kubernetes API is accessible")

    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "status": "healthy",
                    "vault_connected": True,
                    "kubernetes_connected": True
                },
                {
                    "status": "unhealthy",
                    "vault_connected": False,
                    "kubernetes_connected": True
                }
            ]
        }
    }
