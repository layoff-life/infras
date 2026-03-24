"""Abstract base class for infrastructure services."""

from abc import ABC, abstractmethod
from typing import Dict, Any, Optional
import structlog

logger = structlog.get_logger(__name__)


class InfrastructureService(ABC):
    """
    Abstract base class for all infrastructure services.

    All services (MySQL, PostgreSQL, Redis, Kafka, Keycloak) must
    implement this interface to ensure consistent ACL creation.
    """

    def __init__(self, vault_service, k8s_operations):
        """
        Initialize infrastructure service.

        Args:
            vault_service: Vault service instance
            k8s_operations: Kubernetes operations instance
        """
        self.vault = vault_service
        self.k8s = k8s_operations

    @abstractmethod
    async def create_acl(
        self,
        service_name: str,
        password: str,
        **kwargs
    ) -> Dict[str, Any]:
        """
        Create ACL for a service.

        Args:
            service_name: Name of the service
            password: Password for the service
            **kwargs: Additional service-specific parameters (e.g., owner_username for Keycloak)

        Returns:
            Dictionary with connection details and vault path

        Raises:
            Exception: If ACL creation fails
        """
        pass

    @abstractmethod
    async def verify_acl(self, service_name: str) -> bool:
        """
        Verify that ACL was created successfully.

        Args:
            service_name: Name of the service

        Returns:
            True if ACL exists and is working, False otherwise
        """
        pass

    @abstractmethod
    def get_vault_path(self, service_name: str) -> str:
        """
        Get Vault path for storing credentials.

        Args:
            service_name: Name of the service

        Returns:
            Vault path (e.g., "infras/mysql/service_name")
        """
        pass

    async def _store_credential(
        self,
        service_name: str,
        password: str
    ) -> str:
        """
        Store credential in Vault.

        Args:
            service_name: Name of the service
            password: Password to store

        Returns:
            Vault path where credential was stored
        """
        vault_path = self.get_vault_path(service_name)
        await self.vault.store_credential(vault_path, service_name, password)
        logger.info("Stored credential in Vault", vault_path=vault_path)
        return vault_path
