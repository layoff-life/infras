#!/usr/bin/env bash
set -euo pipefail

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Load common library
source "$SCRIPT_DIR/lib/common.sh"

# Usage
usage() {
    echo "Usage: $0 <service_name> <infra_type> [owner_username]"
    echo "  service_name: Name of the service (e.g., 'auth-service', 'payment-service')"
    echo "  infra_type: Type of infrastructure ('app', 'mysql', 'postgres', 'redis', 'kafka', 'keycloak')"
    echo "  owner_username: Required for 'keycloak' type. Realm/user to scope the client to."
    exit 1
}

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    usage
fi

SERVICE_NAME="$1"
INFRA_TYPE="$2"
OWNER_USERNAME="${3:-}"

log_info "Starting ACL setup for service '$SERVICE_NAME' on '$INFRA_TYPE'..."

# Validate Infra Type
case "$INFRA_TYPE" in
    app)
        source "$SCRIPT_DIR/lib/app.sh"
        ;;
    mysql)
        source "$SCRIPT_DIR/lib/mysql.sh"
        ;;
    postgres)
        source "$SCRIPT_DIR/lib/postgres.sh"
        ;;
    redis)
        source "$SCRIPT_DIR/lib/redis.sh"
        ;;
    kafka)
        source "$SCRIPT_DIR/lib/kafka.sh"
        ;;
    keycloak)
        if [ -z "${OWNER_USERNAME:-}" ]; then
            log_error "owner_username is required for keycloak type."
            log_error "Usage: $0 <service_name> keycloak <owner_username>"
            exit 1
        fi
        source "$SCRIPT_DIR/lib/keycloak.sh"
        ;;
    *)
        log_error "Unknown infrastructure type: $INFRA_TYPE"
        usage
        ;;
esac

# Check Vault
check_vault

# Generate Password (not used by 'app' type but kept for other infra types)
if [ "$INFRA_TYPE" != "app" ]; then
    PASSWORD=$(generate_password)
    log_info "Generated password for $SERVICE_NAME"

    # Store in Vault (infras/<infra>/<service>)
    VAULT_PATH="infras/${INFRA_TYPE}/${SERVICE_NAME}"
    store_credential "$VAULT_PATH" "$SERVICE_NAME" "$PASSWORD"
    log_info "Stored credential (username/password) in Vault at $VAULT_PATH"
else
    PASSWORD=""
    VAULT_PATH="apps/${SERVICE_NAME}/${SERVICE_NAME}"
    create_modify_policy "$SERVICE_NAME"
fi

# Execute Infrastructure Specific Setup
create_acl "$SERVICE_NAME" "$PASSWORD" "$OWNER_USERNAME"

# Create Policy, Modify Policy, and Token
create_policy "$SERVICE_NAME"
TOKEN=$(create_token "$SERVICE_NAME")

log_info "ACL setup completed successfully for $SERVICE_NAME on $INFRA_TYPE."
echo ""
echo "==================================================================="
echo "SERVICE: $SERVICE_NAME"
echo "INFRA:   $INFRA_TYPE"
echo "SECRET:  $VAULT_PATH"
echo "TOKEN:   $TOKEN"
echo "==================================================================="
echo "Save this token! It allows access to 'apps/$SERVICE_NAME/*'"
