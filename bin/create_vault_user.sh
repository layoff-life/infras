#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "${ROOT_DIR}/bin/lib/common.sh"

if [ -z "${1:-}" ]; then
  echo "Usage: $0 <username>"
  exit 1
fi

USERNAME=$1

check_vault

# 1. Ensure userpass auth is enabled
if ! docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault-local vault auth list -format=json | jq -e '."userpass/"' > /dev/null; then
    log_info "Enabling userpass auth method..."
    docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault-local vault auth enable userpass >/dev/null
fi

# 2. Check if user already exists
user_exists=$(docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault-local vault read -format=json auth/userpass/users/"$USERNAME" 2>/dev/null || echo "")

if [ -n "$user_exists" ]; then
    log_info "User '$USERNAME' already exists in Vault."
else
    # 3. Generate password and save to Vault
    # We use standard default path: infras/vault/users/<username>
    secret_path="infras/vault/users/$USERNAME"
    log_info "Generating password and storing in Vault at $secret_path..."
    ensure_credential "$secret_path" "$USERNAME"
    
    PASSWORD=$(fetch_secret "$secret_path" password)
    
    # 4. Create userpass user
    log_info "Creating Vault userpass user '$USERNAME'..."
    docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault-local vault write auth/userpass/users/"$USERNAME" password="$PASSWORD" >/dev/null
    
    echo ""
    echo "[OK] Vault user '$USERNAME' created successfully!"
    echo "       Login with Username: $USERNAME"
    echo "       Password stored at: $secret_path"
fi
