#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KEYS_FILE="${ROOT_DIR}/vault_keys.txt"
COMPOSE_FILE="${ROOT_DIR}/redis-local/docker-compose.yml"

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
if [ -f "$KEYS_FILE" ] && [ "$(docker ps -q -f name=vault-local)" ]; then
    echo "[INFO] Vault detected. Fetching secrets..."
    
    # Get Root Token
    export VAULT_TOKEN=$(jq -r ".root_token" "$KEYS_FILE")
    
    # Fetch Secrets
    export REDIS_PASSWORD=$(fetch_secret redis/auth password)
    
    echo "[INFO] Secrets fetched successfully."
else
    echo "[WARN] Vault not detected or keys missing. Using default or existing environment variables."
    # Fallback or error if password is mandatory
    if [ -z "${REDIS_PASSWORD:-}" ]; then
        echo "[ERROR] REDIS_PASSWORD is not set and Vault is not available."
        exit 1
    fi
fi

echo "[INFO] Starting redis-local using ${COMPOSE_FILE}..."
docker compose -f "${COMPOSE_FILE}" up -d
echo "[OK] redis-local is starting. Use 'docker ps' to verify the container."
