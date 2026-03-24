# Infras-CLI Usage Guide

Complete guide for running infras-cli CLI and REST API.

## Quick Start

```bash
# Navigate to project
cd /home/hunghlh/app/infras/minikube/local/k8s-local/infras-cli

# Run CLI directly (no exports needed!)
./infras-cli version
```

**Expected output:** `infras-cli version 1.0.0`

**Note:** The `infras-cli` script automatically configures:
- `VAULT_ADDR` - Uses `http://$(minikube ip):30200` for local development
- `VAULT_TOKEN` - Fetches from Kubernetes secret `vault-root-token` in `infras-vault` namespace

If you're running from within the Kubernetes cluster, it will fall back to `http://vault.infras-vault.svc.cluster.local:8200`.

---

## CLI Commands

### Setup ACL

```bash
# MySQL
./infras-cli setupacl myapp mysql

# PostgreSQL
./infras-cli setupacl myapp postgres

# Redis
./infras-cli setupacl myapp redis

# Kafka
./infras-cli setupacl myapp kafka

# Keycloak (requires realm name)
./infras-cli setupacl myapp keycloak --owner-username myrealm
```

### Verify ACL

```bash
./infras-cli verify-acl myapp mysql
```

### Generate Token

```bash
# Default (24h TTL)
./infras-cli generate-token myapp

# Custom TTL
./infras-cli generate-token myapp --ttl 48h
./infras-cli generate-token myapp --ttl 7d

# Custom policy
./infras-cli generate-token myapp --policy app-myapp
```

### User Management

```bash
# Create user
./infras-cli create-user alice

# Assign policies to user
./infras-cli assign-policy alice myapp
```

### Help

```bash
./infras-cli --help
./infras-cli setupacl --help
```

---

## REST API

### Start Server

```bash
# Start API server (no exports needed!)
./infras-api --port 8000
```

Access API docs at: http://localhost:8000/docs

### API Endpoints

#### Health Check

```bash
curl http://localhost:8000/api/v1/health/ready
```

#### Setup ACL

```bash
curl -X POST http://localhost:8000/api/v1/acl/setup \
  -H "Content-Type: application/json" \
  -d '{
    "service_name": "myapp",
    "infra_type": "mysql"
  }'
```

#### Generate Token

```bash
curl -X POST http://localhost:8000/api/v1/users/token \
  -H "Content-Type: application/json" \
  -d '{
    "app_name": "myapp",
    "ttl": "24h"
  }'
```

#### Create User

```bash
curl -X POST http://localhost:8000/api/v1/users/ \
  -H "Content-Type: application/json" \
  -d '{
    "username": "alice"
  }'
```

#### Assign Policies

```bash
curl -X POST http://localhost:8000/api/v1/users/alice/policies \
  -H "Content-Type: application/json" \
  -d '{
    "app_name": "myapp"
  }'
```

---

## Examples

### Example 1: MySQL Application

```bash
# Setup database
./infras-cli setupacl customerdb mysql

# Generate token
./infras-cli generate-token customerdb --ttl 720h
```

**Output shows:**
- Database: `customerdb`
- Host: `mysql.infras-mysql.svc.cluster.local`
- Port: `3306`
- Username: `customerdb`
- Vault token: `s.xxxxx...`

### Example 2: Multi-Database App

```bash
# Setup multiple databases
./infras-cli setupacl myapp mysql
./infras-cli setupacl myapp redis
./infras-cli setupacl myapp kafka

# All use same token
./infras-cli generate-token myapp
```

### Example 3: Developer Access

```bash
# Create user for developer
./infras-cli create-user john_doe

# Grant access to app
./infras-cli assign-policy john_doe myapp
```

---

## Troubleshooting

### "ModuleNotFoundError: No module named 'app'"

**Problem:** Not in the project directory

**Solution:**
```bash
pwd  # Should be: /home/hunghlh/app/infras/minikube/local/k8s-local/infras-cli
cd /home/hunghlh/app/infras/minikube/local/k8s-local/infras-cli
```

### "Failed to auto-configure VAULT_ADDR"

**Problem:** minikube or kubectl not available

**Solution:**
Set environment variables manually:
```bash
export VAULT_ADDR="http://vault.infras-vault.svc.cluster.local:8200"
export VAULT_TOKEN=$(kubectl get secret vault-root-token -n infras-vault -o jsonpath='{.data.token}' | base64 -d)
./infras-cli <command>
```

### "Connection refused" to Vault

**Problem:** Vault not running

**Solution:**
```bash
kubectl get pods -n infras-vault
kubectl exec -n infras-vault vault-0 -- vault status
```

---

## Infrastructure Types

| Type     | Description                          | Host                                             |
|----------|--------------------------------------|--------------------------------------------------|
| mysql    | MySQL database & user                | mysql.infras-mysql.svc.cluster.local:3306      |
| postgres | PostgreSQL database & user           | postgres.infras-postgres.svc.cluster.local:5432 |
| redis    | Redis ACL user                       | redis-0.redis-headless.infras-redis.svc.cluster.local:6379 |
| kafka    | Kafka SASL user & ACLs               | kafka-0.kafka-headless.infras-kafka.svc.cluster.local:29092 |
| keycloak | Keycloak realm, user & client        | keycloak.infras-keycloak.svc.cluster.local:8080/realms/<realm> |

---

## Quick Reference

```
┌─────────────────────────────────────────────────────────────┐
│  CLI Commands                                              │
├─────────────────────────────────────────────────────────────┤
│  ./infras-cli setupacl <name> <type>                      │
│  ./infras-cli verify-acl <name> <type>                     │
│  ./infras-cli generate-token <name>                        │
│  ./infras-cli create-user <username>                      │
│  ./infras-cli assign-policy <user> <app>                  │
├─────────────────────────────────────────────────────────────┤
│  API Server                                                │
│  ./infras-api --port 8000                                 │
│  Docs: http://localhost:8000/docs                          │
├─────────────────────────────────────────────────────────────┤
│  Environment (Auto-configured by script)                    │
│  VAULT_ADDR=http://$(minikube ip):30200                   │
│  VAULT_TOKEN=$(kubectl get secret ...)                     │
└─────────────────────────────────────────────────────────────┘
```

---

## Tips

**Create aliases for easier use:**

Add to `~/.bashrc` or `~/.zshrc`:
```bash
alias infras-cli='/home/hunghlh/app/infras/minikube/local/k8s-local/infras-cli/infras-cli'
alias infras-api='/home/hunghlh/app/infras/minikube/local/k8s-local/infras-cli/infras-api'
```

Then use from anywhere:
```bash
infras-cli version
infras-cli setupacl myapp mysql
infras-api --port 8000
```

**Note:** The scripts automatically configure Vault credentials, so you don't need to set any environment variables!

---

**Version:** 1.0.0
**Last Updated:** 2026-03-24
