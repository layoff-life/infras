"""FastAPI route modules."""

from fastapi import APIRouter
from .health import router as health_router
from .acl import router as acl_router
from .users import router as users_router

# Create main API router
api_router = APIRouter()

# Include route modules
api_router.include_router(health_router, prefix="/health", tags=["Health"])
api_router.include_router(acl_router, prefix="/acl", tags=["ACL"])
api_router.include_router(users_router, prefix="/users", tags=["Users"])

__all__ = ["api_router"]
