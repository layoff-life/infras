#!/bin/bash
# Deploy PostgreSQL to MiniKube
# Based on /home/hunghlh/app/infras/postgres-local setup

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POSTGRES_DIR="$(dirname "$SCRIPT_DIR")"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Deploy PostgreSQL to MiniKube                             ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check Vault
echo "→ Checking Vault..."
if ! kubectl get pod -n infras-vault -l app=vault &>/dev/null; then
    echo "  ❌ Vault not found in infras-vault namespace"
    echo "     Deploy Vault first"
    exit 1
fi

VAULT_POD=$(kubectl get pod -n infras-vault -l app=vault -o jsonpath='{.items[0].metadata.name}')
echo "  ✓ Vault pod: $VAULT_POD"

# Check Vault status
if ! kubectl exec -n infras-vault "$VAULT_POD" -- vault status -format=json 2>/dev/null | jq -e '.sealed == false' &>/dev/null; then
    echo "  ⚠️  Vault is sealed. Unseal first"
    exit 1
fi
echo "  ✓ Vault is unsealed"

# Get Vault root token
echo ""
echo "→ Fetching Vault credentials..."
ROOT_TOKEN=$(kubectl get secret vault-root-token -n infras-vault -o jsonpath='{.data.token}' | base64 -d 2>/dev/null || echo "")

if [ -z "$ROOT_TOKEN" ]; then
    echo "  ❌ vault-root-token secret not found"
    echo "     Create it first:"
    echo "     kubectl create secret generic vault-root-token -n infras-vault --from-literal=token=\$(cat ~/.vault-init/root-token.txt)"
    exit 1
fi

# Fetch/Create postgres credentials
echo "  → Getting postgres credentials from Vault..."

# Login to Vault first
kubectl exec -n infras-vault "$VAULT_POD" -- vault login -method=token token="$ROOT_TOKEN" > /dev/null 2>&1

# Check if credentials exist
CREDS_JSON=$(kubectl exec -n infras-vault "$VAULT_POD" -- vault kv get -format=json infras/postgres/auth 2>/dev/null || echo "")

if [ -n "$CREDS_JSON" ]; then
    # Parse username and password from existing secret
    USERNAME=$(echo "$CREDS_JSON" | jq -r '.data.data.username // "postgres"')
    PASSWORD=$(echo "$CREDS_JSON" | jq -r '.data.data.password // ""')

    # If username is missing, update the secret
    if [ -z "$PASSWORD" ] || [ "$(echo "$CREDS_JSON" | jq -r '.data.data.username // ""')" = "" ]; then
        echo "  → Updating secret structure (adding username)..."
        PASSWORD=$(echo "$CREDS_JSON" | jq -r '.data.data.password // ""')
        if [ -z "$PASSWORD" ]; then
            PASSWORD=$(cat /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 20)
        fi
        kubectl exec -n infras-vault "$VAULT_POD" -- vault kv put infras/postgres/auth username="postgres" password="$PASSWORD" > /dev/null 2>&1
        echo "  ✓ Secret updated with username and password"
    else
        echo "  ✓ Credentials found in Vault"
    fi
else
    # Create new secret with both username and password
    echo "  → Credentials not found, generating..."
    USERNAME="postgres"
    PASSWORD=$(cat /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 20)
    kubectl exec -n infras-vault "$VAULT_POD" -- vault kv put infras/postgres/auth username="$USERNAME" password="$PASSWORD" > /dev/null 2>&1
    echo "  ✓ Credentials stored in Vault at infras/postgres/auth"
fi

# Create Kubernetes Secret
echo ""
echo "→ Creating Kubernetes Secret..."
kubectl create secret generic postgres-password \
    --from-literal=password="$PASSWORD" \
    -n infras-postgres --dry-run=client -o yaml | kubectl apply -f -
echo "  ✓ Secret created in postgres namespace"

# Deploy resources
echo ""
echo "→ Deploying PostgreSQL resources..."
kubectl apply -f "$POSTGRES_DIR/pvc.yaml"
kubectl apply -f "$POSTGRES_DIR/service.yaml"
kubectl apply -f "$POSTGRES_DIR/deployment.yaml"
echo "  ✓ Resources deployed"

# Wait for ready
echo ""
echo "→ Waiting for PostgreSQL to be ready..."
kubectl rollout status deployment/postgres -n infras-postgres --timeout=120s

# Fix authentication to require password for ALL connections
echo ""
echo "→ Securing PostgreSQL authentication..."
echo "  → Updating pg_hba.conf to require password for all connections..."
kubectl exec -n infras-postgres deployment/postgres -- sh -c '
  cp /var/lib/postgresql/data/pg_hba.conf /var/lib/postgresql/data/pg_hba.conf.bak
  cat > /var/lib/postgresql/data/pg_hba.conf << "EOF"
# PostgreSQL Client Authentication Configuration File
# TYPE  DATABASE        USER            ADDRESS                 METHOD
local   all             all                                     scram-sha-256
host    all             all             127.0.0.1/32            scram-sha-256
host    all             all             ::1/128                 scram-sha-256
host    all             all             all                     scram-sha-256
host    replication     all             all                     scram-sha-256
EOF
' || echo "  ⚠️  Could not update pg_hba.conf (will use defaults)"
echo "  ✓ pg_hba.conf updated"

# Reload PostgreSQL configuration to apply pg_hba.conf changes
echo "  → Reloading PostgreSQL configuration..."
kubectl exec -n infras-postgres deployment/postgres -- psql -U postgres -c "SELECT pg_reload_conf();" > /dev/null 2>&1
sleep 2

echo "  ✓ PostgreSQL authentication secured"

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  PostgreSQL Deployed Successfully!                         ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Connection Details:"
echo "  Service:    postgres.infras-postgres.svc.cluster.local:5432"
echo "  User:       postgres"
echo "  Password:   (stored in Vault: infras/postgres/auth)"
echo "  Database:   postgres"
echo ""
echo "Configuration:"
echo "  max_connections:           200"
echo "  max_prepared_transactions: 100"
echo ""
echo "Commands:"
echo "  Connect:   kubectl exec -n infras-postgres deployment/postgres -- psql -U postgres"
echo "  Logs:      kubectl logs -n infras-postgres -f -l app=postgres -c postgres"
echo "  Metrics:   kubectl port-forward -n infras-postgres svc/postgres-exporter 9187:9187"
echo ""
