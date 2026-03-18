#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KEYS_FILE="${ROOT_DIR}/vault_keys.txt"
COMPOSE_FILE="${ROOT_DIR}/keycloak-local/docker-compose.yml"

# Source Common Library
source "${ROOT_DIR}/bin/lib/common.sh"

echo "[INFO] Starting keycloak-local..."

# Check Vault Availability
check_vault

if [ -n "${VAULT_TOKEN:-}" ]; then
    echo "[INFO] Vault detected. Ensuring/Fetching secrets..."
    
    # Ensure Keycloak Admin credential exists
    ensure_credential "infras/keycloak/auth" "admin"
    export KC_BOOTSTRAP_ADMIN_USERNAME=$(fetch_secret infras/keycloak/auth username)
    export KC_BOOTSTRAP_ADMIN_PASSWORD=$(fetch_secret infras/keycloak/auth password)
    
    # Check if DB is set up by checking if DB secret exists
    # fetch_secret might return empty if it doesn't exist
    db_pass=$(fetch_secret infras/postgres/keycloak password || true)
    
    if [ -z "$db_pass" ] || [ "$db_pass" = "null" ]; then
        echo "[INFO] DB secret not found. Running setup_acl.sh to create Keycloak DB and role..."
        "${ROOT_DIR}/bin/setup_acl.sh" keycloak postgres
    else
        echo "[INFO] DB secret found. Skipping DB setup."
    fi
    
    export KEYCLOAK_DB_USERNAME=$(fetch_secret infras/postgres/keycloak username)
    export KEYCLOAK_DB_PASSWORD=$(fetch_secret infras/postgres/keycloak password)

    echo "[INFO] Secrets fetched successfully."
else
    echo "[WARN] Vault not detected. Cannot start properly without secrets."
    exit 1
fi

echo "[INFO] Starting keycloak container..."
docker compose -f "${COMPOSE_FILE}" up -d
