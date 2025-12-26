#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KEYS_FILE="${ROOT_DIR}/vault_keys.txt"
COMPOSE_FILE="${ROOT_DIR}/mysql-local/docker-compose.yml"

# Function to fetch secret from Vault
fetch_secret() {
    local path=$1
    local field=$2
    if [ -n "${VAULT_TOKEN:-}" ]; then
        docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault-local vault kv get -mount=secret -field="$field" "$path"
    else
        docker exec vault-local vault kv get -mount=secret -field="$field" "$path"
    fi
}

# Check if Vault is running and keys exist
# Using docker ps -q -f name=vault-local to avoid pipefail issues with grep -q
if [ -f "$KEYS_FILE" ] && [ "$(docker ps -q -f name=vault-local)" ]; then
    echo "[INFO] Vault detected. Fetching secrets..."
    
    # Get Root Token
    export VAULT_TOKEN=$(jq -r ".root_token" "$KEYS_FILE")
    
    # Fetch Secrets
    export MYSQL_ROOT_PASSWORD=$(fetch_secret mysql/root password)
    export MYSQL_USER_NAME="my_user"
    export MYSQL_USER_PASSWORD=$(fetch_secret mysql/my_user password)
    export MYSQL_ADMIN_USER="admin"
    export MYSQL_ADMIN_PASSWORD=$(fetch_secret mysql/admin password)
    
    echo "[INFO] Secrets fetched successfully."
else
    echo "[WARN] Vault not detected or keys missing. Falling back to .env file or existing environment variables."
fi

echo "[INFO] Starting mysql-local using ${COMPOSE_FILE}..."
docker compose -f "${COMPOSE_FILE}" up -d
echo "[OK] mysql-local is starting. Use 'docker ps' to verify the container."
