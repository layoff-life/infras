"""Kafka ACL provisioning service."""

import structlog
from typing import Dict, Any

from .base import InfrastructureService

logger = structlog.get_logger(__name__)


class KafkaService(InfrastructureService):
    """Kafka ACL provisioning using kubectl exec and JAAS config updates."""

    async def create_acl(
        self,
        service_name: str,
        password: str,
        **kwargs
    ) -> Dict[str, Any]:
        """
        Create Kafka SASL user and ACLs.

        Args:
            service_name: Name of the service (also Kafka username)
            password: Password for the service user
            **kwargs: Additional parameters (not used for Kafka)

        Returns:
            Dictionary with connection details and vault path
        """
        logger.info("Creating Kafka ACL", service_name=service_name)

        # 1. Fetch admin credentials from Vault
        admin_user = await self.vault.fetch_secret("infras/kafka/sasl", "username")
        admin_pass = await self.vault.fetch_secret("infras/kafka/sasl", "password")

        # 2. Update JAAS Secret with new user
        jaas_line = f"    user_{service_name}=\"{password}\";"

        logger.debug("Updating Kafka JAAS Secret", service_name=service_name)

        try:
            await self.k8s.update_secret(
                namespace="infras-kafka",
                name="kafka-jaas-config",
                key="kafka_server_jaas.conf",
                value=jaas_line,
                append=True
            )
        except Exception as e:
            logger.error("Failed to update Kafka JAAS Secret", error=str(e))
            raise

        # 3. Restart Kafka StatefulSet to reload JAAS config
        logger.info("Restarting Kafka to reload JAAS config")
        await self.k8s.restart_statefulset(
            namespace="infras-kafka",
            name="kafka"
        )

        # 4. Wait for all pods to be ready
        logger.info("Waiting for Kafka to be ready")
        await self.k8s.wait_for_statefulset_ready(
            namespace="infras-kafka",
            name="kafka",
            timeout=120
        )

        # 5. Create ACLs using kafka-acls.sh
        # Topic ACL: ALL operations on service_name-* topics (PREFIXED)
        logger.debug("Creating Kafka topic ACL")

        topic_acl_cmd = [
            "kafka-acls.sh",
            "--bootstrap-server", "localhost:29092",
            "--add",
            "--allow-principal", f"User:{service_name}",
            "--operation", "All",
            "--topic", f"{service_name}-*",
            "--resource-pattern-type", "Prefixed"
        ]

        await self.k8s.exec_command(
            namespace="infras-kafka",
            pod="statefulset/kafka",
            command=topic_acl_cmd
        )

        # Group ACL: ALL operations on service_name-* groups (PREFIXED)
        logger.debug("Creating Kafka group ACL")

        group_acl_cmd = [
            "kafka-acls.sh",
            "--bootstrap-server", "localhost:29092",
            "--add",
            "--allow-principal", f"User:{service_name}",
            "--operation", "All",
            "--group", f"{service_name}-*",
            "--resource-pattern-type", "Prefixed"
        ]

        await self.k8s.exec_command(
            namespace="infras-kafka",
            pod="statefulset/kafka",
            command=group_acl_cmd
        )

        # 6. Store credential in Vault
        vault_path = await self._store_credential(service_name, password)

        logger.info("Kafka ACL created successfully", service_name=service_name, vault_path=vault_path)

        return {
            "bootstrap_servers": "kafka-0.kafka-headless.infras-kafka.svc.cluster.local:29092",
            "username": service_name,
            "vault_path": vault_path
        }

    async def verify_acl(self, service_name: str) -> bool:
        """
        Verify Kafka ACL was created successfully.

        Args:
            service_name: Name of the service

        Returns:
            True if user exists in ACL list, False otherwise
        """
        logger.info("Verifying Kafka ACL", service_name=service_name)

        try:
            admin_user = await self.vault.fetch_secret("infras/kafka/sasl", "username")
            admin_pass = await self.vault.fetch_secret("infras/kafka/sasl", "password")

            # List ACLs for this user
            acl_list = await self.k8s.exec_command(
                namespace="infras-kafka",
                pod="statefulset/kafka",
                command=[
                    "kafka-acls.sh",
                    "--bootstrap-server", "localhost:29092",
                    "--list",
                    "--principal", f"User:{service_name}"
                ]
            )

            # Check if any ACLs exist for this user
            acl_exists = service_name in acl_list or "No ACLs found" not in acl_list

            if acl_exists:
                logger.info("Kafka ACL verified", service_name=service_name)
                return True
            else:
                logger.warning("Kafka ACL verification failed", service_name=service_name)
                return False

        except Exception as e:
            logger.error("Kafka ACL verification error", service_name=service_name, error=str(e))
            return False

    def get_vault_path(self, service_name: str) -> str:
        """
        Get Vault path for storing credentials.

        Args:
            service_name: Name of the service

        Returns:
            Vault path
        """
        return f"infras/kafka/{service_name}"
