#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KEYS_FILE="${ROOT_DIR}/vault_keys.txt"
COMPOSE_FILE="${ROOT_DIR}/redis-local/docker-compose.yml"
ACL_FILE="${ROOT_DIR}/redis-local/users.acl"

# Function to fetch secret from Vault
fetch_secret() {
    local path=$1
    local field=$2
    if [ -n "${VAULT_TOKEN:-}" ]; then
        docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault-local vault kv get -mount=infras -field="$field" "$path"
    else
        docker exec vault-local vault kv get -mount=infras -field="$field" "$path"
    fi
}

# Source Common Library
source "${ROOT_DIR}/bin/lib/common.sh"

echo "[INFO] Starting redis-local..."

# Check Vault Availability
check_vault

if [ -n "${VAULT_TOKEN:-}" ]; then
    echo "[INFO] Vault detected. Ensuring/Fetching secrets..."
    
    # Ensure credential exists
    ensure_credential "infras/redis/auth" "default"
    
    # Fetch Secrets
    export REDIS_PASSWORD=$(fetch_secret infras/redis/auth password)
    
    echo "[INFO] Secrets fetched successfully."
else
    echo "[WARN] Vault not detected or keys missing. Using default or existing environment variables."
    # Fallback or error if password is mandatory
    if [ -z "${REDIS_PASSWORD:-}" ]; then
        echo "[ERROR] REDIS_PASSWORD is not set and Vault is not available."
        exit 1
    fi
fi

# Generate ACL file with actual password if not exist
if [ ! -f "$ACL_FILE" ]; then
    echo "[INFO] Generating ACL file..."
    cat > "$ACL_FILE" <<EOF
user default on >${REDIS_PASSWORD} ~* &* +@all
user worker on >${REDIS_PASSWORD} ~* &* +@all
EOF
else
    echo "[INFO] ACL file exists. Updating default/worker passwords..."
    # Update default and worker passwords while preserving other users
    # We use awk to safely replace the password field (4th field: >password)
    TEMP_ACL=$(mktemp)
    awk -v pass="$REDIS_PASSWORD" '
    /^user default / { $4 = ">" pass }
    /^user worker / { $4 = ">" pass }
    { print }
    ' "$ACL_FILE" > "$TEMP_ACL" && cat "$TEMP_ACL" > "$ACL_FILE" && rm "$TEMP_ACL"
fi

echo "[INFO] Starting redis-local using ${COMPOSE_FILE}..."
docker compose -f "${COMPOSE_FILE}" up -d
echo "[OK] redis-local is starting. Use 'docker ps' to verify the container."
