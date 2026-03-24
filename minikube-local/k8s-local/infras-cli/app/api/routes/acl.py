"""ACL management endpoints for creating and verifying ACLs."""

from fastapi import APIRouter, HTTPException, status
from app.models import ACLSetupRequest, ACLSetupResponse, ACLVerifyRequest, ACLVerifyResponse
from app.services.factory import ServiceFactory
from app.services.vault_service import VaultService
from app.k8s.operations import KubernetesOperations
from app.utils.crypto import generate_password
import structlog

logger = structlog.get_logger(__name__)
router = APIRouter()


@router.post("/setup", response_model=ACLSetupResponse, status_code=status.HTTP_201_CREATED)
async def setup_acl(request: ACLSetupRequest):
    """
    Setup ACL for a service on infrastructure.

    This endpoint:
    1. Creates database/user/ACL for the specified infrastructure
    2. Stores credentials in Vault
    3. Creates Vault policies (app-<name>, modify-<name>)
    4. Generates a Vault token with the app policy

    Args:
        request: ACL setup request with service_name, infra_type, and optional owner_username

    Returns:
        ACLSetupResponse with connection details, vault path, and token

    Raises:
        HTTPException 400: Invalid infrastructure type or missing required parameters
        HTTPException 500: Internal error during ACL creation
    """
    try:
        logger.info(
            "Setting up ACL",
            service_name=request.service_name,
            infra_type=request.infra_type
        )

        # Initialize services
        vault = VaultService()
        k8s = KubernetesOperations()

        # Create infrastructure service
        service = ServiceFactory.create_service(request.infra_type, vault, k8s)

        # Generate password
        password = generate_password()

        # Prepare kwargs for Keycloak (requires owner_username)
        kwargs = {}
        if request.infra_type.lower() == "keycloak":
            if not request.owner_username:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="owner_username is required for Keycloak ACL creation"
                )
            kwargs["owner_username"] = request.owner_username

        # Create ACL
        result = await service.create_acl(
            service_name=request.service_name,
            password=password,
            **kwargs
        )

        # Create Vault policies
        await vault.create_app_policy(request.service_name)
        await vault.create_modify_policy(request.service_name)

        # Generate token
        token = await vault.create_token(
            app_name=request.service_name,
            policy_name=f"app-{request.service_name}"
        )

        logger.info(
            "ACL setup completed successfully",
            service_name=request.service_name,
            vault_path=result.get("vault_path")
        )

        return ACLSetupResponse(
            success=True,
            message=f"ACL created successfully for {request.service_name}",
            vault_path=result.get("vault_path"),
            connection_details=result,
            token=token
        )

    except ValueError as e:
        logger.error("Invalid parameters for ACL setup", error=str(e))
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except HTTPException:
        # Re-raise HTTP exceptions as-is
        raise
    except Exception as e:
        logger.error("ACL setup failed", error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"ACL setup failed: {str(e)}"
        )


@router.post("/verify", response_model=ACLVerifyResponse)
async def verify_acl(request: ACLVerifyRequest):
    """
    Verify ACL exists for a service.

    Checks if the database/user/realm/client was created successfully.

    Args:
        request: ACL verify request with service_name, infra_type, and optional owner_username

    Returns:
        ACLVerifyResponse indicating whether ACL exists

    Raises:
        HTTPException 500: Internal error during verification (not for ACL not found)
    """
    try:
        vault = VaultService()
        k8s = KubernetesOperations()

        service = ServiceFactory.create_service(request.infra_type, vault, k8s)

        # Prepare kwargs for Keycloak
        kwargs = {}
        if request.infra_type.lower() == "keycloak" and request.owner_username:
            kwargs["owner_username"] = request.owner_username

        # Verify ACL
        acl_exists = await service.verify_acl(request.service_name, **kwargs)

        message = "ACL verified" if acl_exists else "ACL not found"

        return ACLVerifyResponse(
            success=acl_exists,
            message=message
        )

    except ValueError as e:
        logger.error("Invalid parameters for ACL verification", error=str(e))
        return ACLVerifyResponse(
            success=False,
            message=f"Invalid parameters: {str(e)}"
        )
    except Exception as e:
        logger.error("ACL verification failed", error=str(e))
        return ACLVerifyResponse(
            success=False,
            message=f"Verification failed: {str(e)}"
        )
