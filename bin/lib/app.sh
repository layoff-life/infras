#!/usr/bin/env bash
# App ACL implementation
# Creates an empty placeholder secret in apps/<service_name>/ and sets up
# the Vault policy/token. No external infrastructure required.

create_acl() {
    local service_name=$1
    # password and owner_username args not used for app type

    # Check if placeholder already exists
    local existing
    existing=$(docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault-local \
        vault kv get -mount=apps -field="$service_name" "$service_name" 2>/dev/null || echo "")

    if [ -n "$existing" ]; then
        log_info "App secret already exists at apps/$service_name. Skipping."
    else
        log_info "Initializing app secret at apps/$service_name..."
        docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault-local \
            vault kv put -mount=apps "$service_name" "$service_name"="$service_name" > /dev/null
        log_info "App secret initialized."
    fi
}
