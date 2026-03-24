"""Health check endpoints for liveness and readiness probes."""

from fastapi import APIRouter, Response, status
from app.models import HealthResponse
from app.services.vault_service import VaultService
from app.k8s.operations import KubernetesOperations
import structlog

logger = structlog.get_logger(__name__)
router = APIRouter()


@router.get("/live", response_class=Response)
async def liveness():
    """
    Liveness probe - checks if the process is running.

    Returns 200 if the service is alive (process is running).
    This is a lightweight check that should always succeed if the process is up.
    """
    return Response(status_code=status.HTTP_200_OK)


@router.get("/ready", response_model=HealthResponse)
async def readiness():
    """
    Readiness probe - checks if dependencies are healthy.

    Returns service health status including:
    - Vault connectivity
    - Kubernetes API connectivity

    Returns unhealthy if any dependency is unreachable.
    """
    try:
        # Initialize services to check connectivity
        vault = VaultService()
        k8s = KubernetesOperations()

        # Check connections (these are lightweight operations)
        vault_ok = await vault.check_connection()
        k8s_ok = await k8s.check_connection()

        overall_status = "healthy" if vault_ok and k8s_ok else "unhealthy"

        if not vault_ok:
            logger.warning("Readiness check: Vault not connected")

        if not k8s_ok:
            logger.warning("Readiness check: Kubernetes not connected")

        return HealthResponse(
            status=overall_status,
            vault_connected=vault_ok,
            kubernetes_connected=k8s_ok
        )

    except Exception as e:
        logger.error("Readiness check failed", error=str(e))
        return HealthResponse(
            status="unhealthy",
            vault_connected=False,
            kubernetes_connected=False
        )
