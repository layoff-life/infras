# Docker Compose to MiniKube Migration Plan

## Context

This plan migrates the existing Docker Compose infrastructure to MiniKube, enabling better resource management, system monitoring, and production-like Kubernetes deployment. The current infrastructure runs 7 services (Vault, 3-node Kafka Cluster, PostgreSQL, MySQL, 3-node Redis Cluster, Keycloak, RedisInsight) with bash-based ACL management scripts.

The migration creates a new `k8s-local/` folder from scratch, preserving the existing Docker Compose setup for reference and rollback.

---

## Technology Stack Choices

**ACL Management Application:**
- **Language**: Python 3.11+ (excellent ecosystem for infrastructure automation)
- **CLI Framework**: Typer (rich CLI experience with progress bars)
- **API Framework**: FastAPI (async REST API for automation and CI/CD)
- **Key Libraries**:
  - `hvac` - Vault client
  - `kubernetes` - Python K8s client
  - `mysql-connector-python` - MySQL driver
  - `psycopg2-binary` - PostgreSQL driver
  - `redis` - Redis client with async support
  - `confluent-kafka` - Kafka admin client

**Monitoring Stack:**
- Prometheus + Grafana + Loki (full observability)
- Service exporters (MySQL, PostgreSQL, Redis, Kafka JMX)
- Pre-built dashboards for all infrastructure components

**Service Access:**
- NGINX Ingress Controller for external access
- Single entry point on port 80/443
- Production-like routing with domain-based access

---

## Directory Structure

```
k8s-local/
├── README.md                           # Complete setup and usage guide
├── up.sh                               # Deploy all infrastructure
├── down.sh                             # Teardown all infrastructure
├── namespaces/
│   ├── 00-namespaces.yaml              # All 8 namespaces
│   └── resource-quotas.yaml            # Resource limits per namespace
├── ingress/
│   ├── nginx-ingress-controller.yaml   # NGINX Ingress Controller
│   └── ingress-routes.yaml             # Ingress routes for services
├── vault/
│   ├── statefulset.yaml                # Vault StatefulSet
│   ├── service.yaml                    # ClusterIP and NodePort services
│   ├── configmap.yaml                  # Vault config.hcl
│   └── pvc.yaml                        # Persistent volume claims
├── mysql/
│   ├── deployment.yaml                 # MySQL deployment with exporter
│   ├── service.yaml                    # ClusterIP service
│   ├── configmap.yaml                  # MySQL configuration
│   └── pvc.yaml                        # Data persistence
├── postgres/
│   ├── deployment.yaml                 # PostgreSQL deployment with exporter
│   ├── service.yaml                    # ClusterIP service
│   ├── configmap.yaml                  # PostgreSQL configuration
│   └── pvc.yaml                        # Data persistence
├── redis/
│   ├── statefulset.yaml                # 3-node Redis Cluster
│   ├── service-headless.yaml           # Headless service for cluster
│   ├── service-external.yaml           # External access via Ingress
│   ├── configmap.yaml                  # Redis configuration
│   └── pvc.yaml                        # Persistent volumes
├── kafka/
│   ├── statefulset.yaml                # 3-node Kafka cluster (KRaft mode)
│   ├── service-headless.yaml           # Headless service for inter-broker
│   ├── service-external.yaml           # External access via Ingress
│   ├── configmap.yaml                  # Kafka server.properties
│   ├── secret.yaml                     # JAAS configuration (managed by app)
│   └── pvc.yaml                        # Persistent volumes
├── keycloak/
│   ├── deployment.yaml                 # Keycloak with PostgreSQL backend
│   ├── service.yaml                    # External access via Ingress
│   ├── configmap.yaml                  # Environment variables
│   └── pvc.yaml                        # Data persistence
├── monitoring/
│   ├── prometheus/
│   │   ├── statefulset.yaml
│   │   ├── configmap.yaml              # Prometheus configuration
│   │   └── pvc.yaml
│   ├── grafana/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml              # Grafana configuration
│   │   └── dashboards/                 # Pre-built JSON dashboards
│   ├── loki/
│   │   ├── statefulset.yaml
│   │   └── configmap.yaml
│   ├── promtail/
│   │   └── daemonset.yaml
│   └── exporters/
│       ├── mysql-exporter.yaml         # Sidecar for MySQL
│       ├── postgres-exporter.yaml      # Sidecar for PostgreSQL
│       ├── redis-exporter.yaml         # Sidecar for Redis
│       └── kafka-jmx-exporter.yaml     # Sidecar for Kafka
└── infras-cli/
    ├── app/
    │   ├── __init__.py
    │   ├── main.py                     # CLI + FastAPI app entry point
    │   ├── config.py                   # Pydantic settings
    │   ├── models/
    │   │   ├── vault.py
    │   │   ├── service.py
    │   │   └── acl.py
    │   ├── services/
    │   │   ├── vault_service.py        # Vault operations
    │   │   ├── mysql_service.py        # MySQL ACL setup
    │   │   ├── postgres_service.py     # PostgreSQL ACL setup
    │   │   ├── redis_service.py        # Redis ACL setup
    │   │   ├── kafka_service.py        # Kafka ACL setup
    │   │   └── keycloak_service.py     # Keycloak realm/client setup
    │   ├── k8s/
    │   │   ├── client.py               # K8s client wrapper
    │   │   └── operations.py           # K8s operations (restart, exec, etc)
    │   └── utils/
    │       ├── logging.py              # Structured logging (structlog)
    │       ├── crypto.py               # Password generation
    │       └── validators.py           # Input validation
    ├── tests/
    │   ├── conftest.py
    │   ├── test_vault_service.py
    │   ├── test_mysql_service.py
    │   ├── test_postgres_service.py
    │   ├── test_redis_service.py
    │   ├── test_kafka_service.py
    │   └── test_keycloak_service.py
    ├── deployment.yaml                 # Deployment in K8s
    ├── service.yaml                    # ClusterIP service
    ├── rbac.yaml                       # ClusterRole and bindings
    ├── configmap.yaml                  # Application config
    ├── Dockerfile
    ├── pyproject.toml
    └── requirements.txt
```

---

## Namespace Architecture

**8 Namespaces for Resource Isolation:**

1. **infras-vault** - HashiCorp Vault with Raft storage
2. **infras-kafka** - 3-node Kafka cluster
3. **infras-mysql** - MySQL 8.0
4. **infras-postgres** - PostgreSQL 17
5. **infras-redis** - 3-node Redis Cluster
6. **infras-keycloak** - Keycloak identity server
7. **infras-monitoring** - Prometheus, Grafana, Loki, Promtail
8. **infras-management** - ACL management application

**Resource Quotas per Namespace (optimized for 8CPU - 16GB RAM):**
- Vault: 0.5CPU, 1GB RAM (requests: 0.25CPU, 512MB)
- Kafka: 2CPU, 3GB RAM (3 brokers, ~0.67CPU each)
- MySQL: 0.5CPU, 1GB RAM (requests: 0.25CPU, 512MB)
- PostgreSQL: 0.5CPU, 1GB RAM (requests: 0.25CPU, 512MB)
- Redis: 1CPU, 2GB RAM (3 nodes, ~0.33CPU each)
- Keycloak: 0.5CPU, 1GB RAM (requests: 0.25CPU, 512MB)
- Monitoring: 2CPU, 5GB RAM (Prometheus 1CPU/2GB, Grafana 0.5CPU/1GB, Loki 0.5CPU/2GB)
- Management: 0.5CPU, 1GB RAM (requests: 0.1CPU, 256MB)
- **Total: ~7.5CPU, 15GB RAM** (within 8CPU, 16GB RAM limits)

---

## Implementation Task List

### Phase 1: Foundation

- **[P1-001]** Verify and configure MiniKube with 8CPU, 16GB RAM, 50GB disk
- **[P1-002]** Create k8s-local directory structure
- **[P1-003]** Create 8 namespace manifests (namespaces/00-namespaces.yaml)
- **[P1-004]** Configure resource quotas for each namespace
- **[P1-005]** Deploy NGINX Ingress Controller
- **[P1-006]** Configure IngressClass for ingress routes
- **[P1-007]** Deploy Prometheus StatefulSet with resource limits (1CPU, 2GB)
- **[P1-008]** Deploy Grafana Deployment with resource limits (0.5CPU, 1GB)
- **[P1-009]** Configure Prometheus data source in Grafana
- **[P1-010]** Test metric collection and verify connectivity

### Phase 2: Core Services

- **[P2-001]** Create Vault StatefulSet manifest (0.5CPU, 1GB RAM)
- **[P2-002]** Create Vault config.hcl ConfigMap
- **[P2-003]** Create Vault services (ClusterIP, NodePort)
- **[P2-004]** Create Vault PVC for data persistence (10Gi)
- **[P2-005]** Deploy Vault to infras-vault namespace
- **[P2-006]** Initialize Vault and save unseal keys and root token
- **[P2-007]** Enable KV v2 secrets engines (infras, apps)
- **[P2-008]** Enable userpass auth method
- **[P2-009]** Store Vault root token in Secret for init containers
- **[P2-010]** Create MySQL Deployment manifest (0.5CPU, 1GB RAM)
- **[P2-011]** Create MySQL my.cnf ConfigMap
- **[P2-012]** Create MySQL init container to fetch root password from Vault
- **[P2-013]** Create MySQL PVC for data persistence (5Gi)
- **[P2-014]** Create MySQL exporter sidecar manifest
- **[P2-015]** Deploy MySQL to infras-mysql namespace
- **[P2-016]** Test MySQL connectivity and metrics
- **[P2-017]** Create PostgreSQL Deployment manifest (0.5CPU, 1GB RAM)
- **[P2-018]** Create PostgreSQL postgresql.conf ConfigMap
- **[P2-019]** Create PostgreSQL init container to fetch admin password from Vault
- **[P2-020]** Create PostgreSQL PVC for data persistence (5Gi)
- **[P2-021]** Create PostgreSQL exporter sidecar manifest
- **[P2-022]** Deploy PostgreSQL to infras-postgres namespace
- **[P2-023]** Test PostgreSQL connectivity and metrics

### Phase 3: Complex Services

- **[P3-001]** Create Redis StatefulSet manifest with 3 replicas (1CPU, 2GB RAM total)
- **[P3-002]** Create Redis redis.conf ConfigMap with ACL enabled
- **[P3-003]** Create Redis headless service for cluster communication
- **[P3-004]** Create Redis PVCs for data persistence (2Gi × 3 = 6Gi)
- **[P3-005]** Create Redis cluster initialization init container
- **[P3-006]** Create Redis exporter sidecar manifest
- **[P3-007]** Deploy Redis Cluster to infras-redis namespace
- **[P3-008]** Test Redis cluster connectivity and ACL functionality
- **[P3-009]** Create Kafka StatefulSet manifest with 3 replicas (2CPU, 3GB RAM total)
- **[P3-010]** Create Kafka server.properties ConfigMap (KRaft mode, SASL)
- **[P3-011]** Create Kafka JAAS Secret (managed by infras-cli app)
- **[P3-012]** Create Kafka headless service for inter-broker communication
- **[P3-013]** Create Kafka PVCs for data persistence (5Gi × 3 = 15Gi)
- **[P3-014]** Create Kafka JMX exporter sidecar manifest
- **[P3-015]** Deploy Kafka Cluster to infras-kafka namespace
- **[P3-016]** Test Kafka cluster health and SASL authentication
- **[P3-017]** Create Keycloak Deployment manifest (0.5CPU, 1GB RAM)
- **[P3-018]** Create Keycloak environment ConfigMap
- **[P3-019]** Create Keycloak PVC for data persistence (2Gi)
- **[P3-020]** Create Keycloak Ingress route for external access
- **[P3-021]** Deploy Keycloak to infras-keycloak namespace
- **[P3-022]** Test Keycloak admin UI access

### Phase 4: Application Development

- **[P4-001]** Create infras-cli Python project structure
- **[P4-002]** Create pyproject.toml with dependencies (FastAPI, Typer, hvac, kubernetes, etc.)
- **[P4-003]** Implement Vault service (vault_service.py) with hvac client
- **[P4-004]** Implement Kubernetes operations (k8s/operations.py)
- **[P4-005]** Implement CLI framework with Typer (main.py)
- **[P4-006]** Implement FastAPI REST API endpoints (main.py)
- **[P4-007]** Implement structured logging with structlog
- **[P4-008]** Implement input validation with Pydantic
- **[P4-009]** Implement MySQL service (mysql_service.py)
- **[P4-010]** Implement PostgreSQL service (postgres_service.py)
- **[P4-011]** Implement Redis service (redis_service.py)
- **[P4-012]** Implement Kafka service (kafka_service.py)
- **[P4-013]** Implement Keycloak service (keycloak_service.py)
- **[P4-014]** Implement user management (create Vault userpass users)
- **[P4-015]** Implement policy assignment (assign app policies to users)
- **[P4-016]** Create unit tests for all services
- **[P4-017]** Create integration tests
- **[P4-018]** Test all ACL operations end-to-end

### Phase 5: Application Deployment

- **[P5-001]** Create Dockerfile for infras-cli application
- **[P5-002]** Build Docker image: `docker build -t infras-cli:latest ./k8s-local/infras-cli/`
- **[P5-003]** Load image into MiniKube: `minikube image load infras-cli:latest`
- **[P5-004]** Create infras-cli Deployment manifest (0.5CPU, 1GB RAM)
- **[P5-005]** Create ServiceAccount for infras-cli
- **[P5-006]** Create ClusterRole with necessary permissions (pods, configmaps, secrets, deployments, statefulsets)
- **[P5-007]** Create ClusterRoleBinding
- **[P5-008]** Create infras-cli ConfigMap for application configuration
- **[P5-009]** Deploy infras-cli to infras-management namespace
- **[P5-010]** Test CLI commands via kubectl exec
- **[P5-011]** Test REST API via port-forward
- **[P5-012]** Verify all ACL operations work correctly

### Phase 6: Finalization

- **[P6-001]** Create comprehensive k8s-local/README.md
- **[P6-002]** Document all K8s manifests with comments
- **[P6-003]** Create usage examples for CLI and API
- **[P6-004]** Add troubleshooting guide to README
- **[P6-005]** Document backup and recovery procedures
- **[P6-006]** Create up.sh script for automated deployment
- **[P6-007]** Create down.sh script for automated teardown
- **[P6-008]** Deploy Loki for centralized logging (0.5CPU, 2GB RAM)
- **[P6-009]** Deploy Promtail DaemonSet for log collection
- **[P6-010]** Create Grafana dashboards for all services (Vault, Kafka, MySQL, PostgreSQL, Redis, Keycloak)
- **[P6-011]** Test log aggregation in Loki
- **[P6-012]** End-to-end testing of all workflows
- **[P6-013]** Load testing with multiple services
- **[P6-014]** Optimize resource limits based on actual usage
- **[P6-015]** Test rollback procedures

---

## Application CLI and API Usage

**CLI Examples (via kubectl exec):**
```bash
# Setup ACL for MySQL service
kubectl exec -n infras-management deployment/infras-cli -- \
  infras-cli setupacl payment-service mysql

# Setup ACL for Keycloak with multi-tenant realm
kubectl exec -n infras-management deployment/infras-cli -- \
  infras-cli setupacl auth-service keycloak --owner-username john

# Create Vault user
kubectl exec -n infras-management deployment/infras-cli -- \
  infras-cli create-user alice

# Assign policy to user
kubectl exec -n infras-management deployment/infras-cli -- \
  infras-cli assign-policy alice payment-service

# Check infrastructure status
kubectl exec -n infras-management deployment/infras-cli -- \
  infras-cli status
```

**REST API Examples (via port-forward or Ingress):**
```bash
# Port-forward to API
kubectl port-forward -n infras-management deployment/infras-cli 8000:8000

# Setup ACL via API
curl -X POST http://localhost:8000/api/v1/acl \
  -H "Content-Type: application/json" \
  -d '{"service_name": "payment-service", "infra_type": "mysql"}'

# Create user via API
curl -X POST http://localhost:8000/api/v1/users \
  -H "Content-Type: application/json" \
  -d '{"username": "alice"}'

# Assign policy via API
curl -X POST http://localhost:8000/api/v1/users/alice/policies \
  -H "Content-Type: application/json" \
  -d '{"app_name": "payment-service"}'
```

---

## Key Implementation Details

### Vault Integration Pattern

All services use init containers to fetch secrets from Vault at startup:

```yaml
initContainers:
- name: fetch-vault-secret
  image: hashicorp/vault:1.15
  command:
  - sh
  - -c
  - |
    vault login -method=token token=${VAULT_TOKEN}
    vault kv get -field=password infras/mysql/root > /tmp/root-password
  env:
  - name: VAULT_ADDR
    value: "http://vault.infras-vault.svc.cluster.local:8200"
  - name: VAULT_TOKEN
    valueFrom:
      secretKeyRef:
        name: vault-root-token
        key: token
  volumeMounts:
  - name: mysql-secrets
    mountPath: /tmp
```

### Service Discovery

Kubernetes DNS replaces Docker Compose networking:
- **Docker Compose**: `mysql-local` (container name)
- **Kubernetes**: `mysql.infras-mysql.svc.cluster.local` (service.namespace.svc.cluster.local)

### Kafka ACL Management Flow

1. infras-cli app receives ACL request
2. App updates Kafka JAAS ConfigMap/Secret with new user
3. App creates Kafka ACLs via AdminClient API
4. App restarts Kafka pods via K8s API to reload JAAS config
5. Verification that ACL is active

### Redis ACL Management Flow

1. infras-cli app receives ACL request
2. App updates Redis ACL ConfigMap with new user
3. App executes `ACL LOAD` on all Redis nodes via `kubectl exec`
4. Verification that ACL is active

---

## Operational Procedures

### Startup Sequence

```bash
cd k8s-local
./up.sh
```

**Script executes in order:**
1. Start MiniKube (if not running) with 8CPU, 16GB RAM
2. Create namespaces
3. Deploy NGINX Ingress Controller
4. Deploy monitoring stack (Prometheus, Grafana, Loki)
5. Deploy Vault
6. Manual Vault initialization (prompt user)
7. Deploy MySQL, PostgreSQL
8. Deploy Redis Cluster
9. Deploy Kafka Cluster
10. Deploy Keycloak
11. Deploy infras-cli application
12. Run health checks
13. Display service URLs

### Shutdown Sequence

```bash
cd k8s-local
./down.sh
```

**Script executes in order:**
1. Stop infras-cli
2. Stop Keycloak
3. Stop Redis, Kafka
4. Stop MySQL, PostgreSQL
5. Stop Vault
6. Stop monitoring
7. Stop NGINX Ingress
8. Delete namespaces
9. Stop MiniKube (optional)

### Vault Unsealing

After Vault pod restart, manual unseal required:
```bash
kubectl exec -n infras-vault statefulset/vault -- vault operator unseal
# Prompts for 3 unseal keys (from vault_keys.txt)
```

---

## Verification and Testing

### End-to-End Test

```bash
# 1. Setup ACL for MySQL service
kubectl exec -n infras-management deployment/infras-cli -- \
  infras-cli setupacl test-mysql-app mysql

# 2. Verify Vault policy exists
kubectl exec -n infras-management deployment/infras-cli -- \
  vault policy read app-test-mysql-app

# 3. Verify MySQL database and user exist
kubectl exec -n infras-mysql deployment/mysql -- \
  mysql -u root -p$(vault kv get -field=password infras/mysql/root) \
  -e "SHOW DATABASES LIKE 'test-mysql-app';"

# 4. Create Vault user
kubectl exec -n infras-management deployment/infras-cli -- \
  infras-cli create-user testuser

# 5. Assign policy to user
kubectl exec -n infras-management deployment/infras-cli -- \
  infras-cli assign-policy testuser test-mysql-app

# 6. Test user access (should succeed)
# 7. Test unauthorized access (should fail)
```

### Monitoring Verification

Access Grafana: `http://grafana.local` (via Ingress)
- Verify all dashboards receiving data
- Check metrics for all services
- Verify log aggregation in Loki

---

## Rollback Strategy

If critical issues occur:

1. **Immediate Rollback to Docker Compose:**
   ```bash
   cd k8s-local && ./down.sh
   cd ../vault-local && ./up.sh
   cd ../mysql-local && ./up.sh
   # ... start other services
   ```

2. **Data Recovery:**
   - PVCs are retained by default (ReclaimPolicy: Retain)
   - Manual backup of `/data` in MiniKube before destructive operations

3. **Configuration Rollback:**
   - Git revert of K8s manifests
   - `kubectl apply -f k8s-local/` with previous version

---

## Critical Files for Implementation

**Must implement first (in order):**

1. **k8s-local/namespaces/00-namespaces.yaml** ([P1-003]) - Foundation for all services
2. **k8s-local/vault/statefulset.yaml** ([P2-001]) - Central security backbone
3. **infras-cli/app/services/vault_service.py** ([P4-003]) - Vault integration for all operations
4. **k8s-local/kafka/statefulset.yaml** ([P3-009]) - Most complex service configuration
5. **infras-cli/app/main.py** ([P4-005], [P4-006]) - CLI + API entry point orchestrating all operations

**Referenced from existing setup (DO NOT MODIFY):**

- `/home/hunghlh/app/infras/bin/setup_acl.sh` - Logic reference for ACL operations
- `/home/hunghlh/app/infras/bin/lib/common.sh` - Vault operation patterns
- `/home/hunghlh/app/infras/bin/lib/mysql.sh` - MySQL ACL logic
- `/home/hunghlh/app/infras/bin/lib/postgres.sh` - PostgreSQL ACL logic
- `/home/hunghlh/app/infras/bin/lib/redis.sh` - Redis ACL logic
- `/home/hunghlh/app/infras/bin/lib/kafka.sh` - Kafka ACL logic
- `/home/hunghlh/app/infras/bin/lib/keycloak.sh` - Keycloak realm logic
- `/home/hunghlh/app/infras/kafka-local/docker-compose.yml` - Kafka configuration reference
- `/home/hunghlh/app/infras/vault-local/config/config.hcl` - Vault configuration reference

---

## Success Criteria

✅ All 7 services deployed and operational on MiniKube
✅ ACL management application deployed and functional
✅ CLI and REST API interfaces working
✅ All monitoring dashboards receiving metrics
✅ End-to-end ACL setup workflow verified for all 6 infrastructure types
✅ Resource consumption within MiniKube limits (8CPU, 16GB RAM)
✅ Documentation complete
✅ Rollback procedures tested
