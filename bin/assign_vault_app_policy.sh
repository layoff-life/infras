#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "${ROOT_DIR}/bin/lib/common.sh"

if [ -z "${1:-}" ] || [ -z "${2:-}" ]; then
  echo "Usage: $0 <username> <app_name>"
  echo "Example: $0 hunghlh mowise"
  exit 1
fi

USERNAME=$1
APP_NAME=$2

check_vault

# 1. Check if user exists
user_data=$(docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault-local vault read -format=json auth/userpass/users/"$USERNAME" 2>/dev/null || echo "")
if [ -z "$user_data" ]; then
    log_error "Vault user '$USERNAME' does not exist. Run: bin/create_vault_user.sh $USERNAME"
    exit 1
fi

# 2. Check that the app has been registered
for pol in "app-${APP_NAME}" "modify-${APP_NAME}"; do
    if ! docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault-local vault policy read "$pol" >/dev/null 2>&1; then
        log_error "Policy '$pol' not found. Run: setup_acl.sh $APP_NAME app"
        exit 1
    fi
done

# 3. Assign both app-<app> (reads) and modify-<app> (writes) to the user
existing_policies=$(echo "$user_data" | jq -r '.data.policies // []')
new_policies_json="$existing_policies"

for pol in "app-${APP_NAME}" "modify-${APP_NAME}"; do
    if echo "$new_policies_json" | jq -e ". | index(\"$pol\")" >/dev/null 2>&1; then
        log_info "Policy '$pol' already assigned. Skipping."
    else
        new_policies_json=$(echo "$new_policies_json" | jq "(. + [\"$pol\"]) | unique")
    fi
done

new_policies_string=$(echo "$new_policies_json" | jq -r 'join(",")')
log_info "Updating policies for user '$USERNAME'..."
docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault-local vault write auth/userpass/users/"$USERNAME" policies="$new_policies_string" >/dev/null

echo "[OK] User '$USERNAME' assigned: app-${APP_NAME} (read) + modify-${APP_NAME} (write)"
