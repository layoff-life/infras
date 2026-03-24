"""Kubernetes client initialization."""

from kubernetes import client, config
from typing import Optional
import structlog

from ..config import settings

logger = structlog.get_logger(__name__)


class KubernetesClient:
    """Kubernetes client wrapper with initialization logic."""

    def __init__(self, kubeconfig_path: Optional[str] = None):
        """
        Initialize Kubernetes client.

        Args:
            kubeconfig_path: Optional path to kubeconfig file.
                             If None, loads from default locations or in-cluster config.
        """
        try:
            if kubeconfig_path:
                config.load_kube_config(config_file=kubeconfig_path)
                logger.info("Loaded kubeconfig from file", path=kubeconfig_path)
            else:
                # Try in-cluster config first (when running in K8s)
                try:
                    config.load_incluster_config()
                    logger.info("Loaded in-cluster Kubernetes config")
                except config.ConfigException:
                    # Fall back to default kubeconfig location
                    config.load_kube_config()
                    logger.info("Loaded default kubeconfig")
        except Exception as e:
            logger.error("Failed to load Kubernetes config", error=str(e))
            raise

        # Initialize API clients
        self.core_v1 = client.CoreV1Api()
        self.apps_v1 = client.AppsV1Api()
        self.batch_v1 = client.BatchV1Api()

        logger.info("Kubernetes client initialized successfully")

    def get_core_api(self) -> client.CoreV1Api:
        """Get CoreV1Api instance."""
        return self.core_v1

    def get_apps_api(self) -> client.AppsV1Api:
        """Get AppsV1Api instance."""
        return self.apps_v1

    def get_batch_api(self) -> client.BatchV1Api:
        """Get BatchV1Api instance."""
        return self.batch_v1


# Global client instance
_k8s_client: Optional[KubernetesClient] = None


def get_k8s_client() -> KubernetesClient:
    """
    Get or create global Kubernetes client instance.

    Returns:
        KubernetesClient instance
    """
    global _k8s_client
    if _k8s_client is None:
        _k8s_client = KubernetesClient()
    return _k8s_client
