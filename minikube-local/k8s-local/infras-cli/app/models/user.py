"""Pydantic models for user management operations."""

from pydantic import BaseModel, Field
from typing import List, Optional


class UserCreateRequest(BaseModel):
    """Request model for user creation.

    Attributes:
        username: Username for Vault userpass authentication
    """
    username: str = Field(..., description="Username for Vault userpass", min_length=1, pattern="^[a-zA-Z0-9_-]+$")

    model_config = {
        "json_schema_extra": {
            "examples": [
                {"username": "john_doe"},
                {"username": "service-account"}
            ]
        }
    }


class UserCreateResponse(BaseModel):
    """Response model for user creation.

    Attributes:
        success: Whether the user was created successfully
        message: Human-readable message
        username: Username of the created user
        vault_path: Path where user credentials are stored in Vault
        password: Auto-generated password (only shown on creation)
    """
    success: bool = Field(..., description="Whether the operation was successful")
    message: str = Field(..., description="Human-readable message")
    username: str = Field(..., description="Username of the created user")
    vault_path: str = Field(..., description="Vault path where user credentials are stored")
    password: str = Field(..., description="Auto-generated password (only shown on creation)")


class PolicyAssignRequest(BaseModel):
    """Request model for policy assignment.

    Attributes:
        username: Username to assign policies to
        app_name: Application name (used to create app-<name> and modify-<name> policies)
    """
    username: str = Field(..., description="Username to assign policies to", min_length=1)
    app_name: str = Field(..., description="Application name for policy creation", min_length=1)

    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "username": "john_doe",
                    "app_name": "myapp"
                }
            ]
        }
    }


class PolicyAssignResponse(BaseModel):
    """Response model for policy assignment.

    Attributes:
        success: Whether policies were assigned successfully
        message: Human-readable message
        username: Username that policies were assigned to
        policies: List of policy names assigned
    """
    success: bool = Field(..., description="Whether the operation was successful")
    message: str = Field(..., description="Human-readable message")
    username: str = Field(..., description="Username that policies were assigned to")
    policies: List[str] = Field(..., description="List of policy names assigned")


class TokenGenerateRequest(BaseModel):
    """Request model for token generation.

    Attributes:
        app_name: Application name for token generation
        policy_name: Policy name (default: app-<app_name>)
        ttl: Token time-to-live (default: 24h)
    """
    app_name: str = Field(..., description="Application name", min_length=1)
    policy_name: Optional[str] = Field(None, description="Policy name (default: app-<app_name>)")
    ttl: str = Field("24h", description="Token time-to-live (e.g., 24h, 48h, 7d)")

    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "app_name": "myapp",
                    "ttl": "24h"
                },
                {
                    "app_name": "myapp",
                    "policy_name": "app-myapp",
                    "ttl": "48h"
                }
            ]
        }
    }


class TokenGenerateResponse(BaseModel):
    """Response model for token generation.

    Attributes:
        success: Whether token was generated successfully
        app_name: Application name
        policy_name: Policy name attached to token
        ttl: Token time-to-live
        token: Generated Vault token
        message: Human-readable message
    """
    success: bool = Field(..., description="Whether the operation was successful")
    app_name: str = Field(..., description="Application name")
    policy_name: str = Field(..., description="Policy name attached to token")
    ttl: str = Field(..., description="Token time-to-live")
    token: str = Field(..., description="Generated Vault token")
    message: str = Field(..., description="Human-readable message")
