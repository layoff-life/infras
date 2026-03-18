#!/usr/bin/env bash

create_acl() {
    local service_name=$1
    local password=$2
    local owner_username=${3:-}

    if [ -z "$owner_username" ]; then
        log_error "owner_username is required for keycloak ACL setup."
        log_error "Usage: setup_acl.sh <service_name> keycloak <owner_username>"
        exit 1
    fi

    # Fetch Admin Credentials
    log_info "Fetching Keycloak admin credentials..."
    local admin_user=$(fetch_secret infras/keycloak/auth username)
    local admin_pass=$(fetch_secret infras/keycloak/auth password)
    
    if [ -z "$admin_pass" ]; then
        log_error "Failed to fetch Keycloak admin password from Vault."
        exit 1
    fi

    log_info "Authenticating with Keycloak..."
    docker exec keycloak-local /opt/keycloak/bin/kcadm.sh config credentials \
        --server http://localhost:8080 --realm master --user "$admin_user" --password "$admin_pass" || {
        log_error "Failed to authenticate to Keycloak. Is it running?"
        exit 1
    }

    local target_realm="$owner_username"
        
    # 1. Create realm if it doesn't exist
    local realm_exists=$(docker exec keycloak-local /opt/keycloak/bin/kcadm.sh get realms/"$target_realm" | jq -r '.id // empty' || true)
    if [ -z "$realm_exists" ]; then
        log_info "Creating dedicated realm '$target_realm' for user '$owner_username'..."
        docker exec keycloak-local /opt/keycloak/bin/kcadm.sh create realms -s realm="$target_realm" -s enabled=true >/dev/null
    else
        log_info "Realm '$target_realm' already exists."
    fi

    # 2. Create the User (Realm Admin) inside their own realm
    local user_exists=$(docker exec keycloak-local /opt/keycloak/bin/kcadm.sh get users -r "$target_realm" -q username="$owner_username" | jq -r '.[0] // empty' || true)
    if [ -z "$user_exists" ]; then
        log_info "Creating admin user '$owner_username' in realm '$target_realm'..."
        local user_pass=$(generate_password)
        store_credential "infras/keycloak/users/$owner_username" "$owner_username" "$user_pass"
        
        docker exec keycloak-local /opt/keycloak/bin/kcadm.sh create users -r "$target_realm" -s username="$owner_username" -s enabled=true >/dev/null
        docker exec keycloak-local /opt/keycloak/bin/kcadm.sh set-password -r "$target_realm" --username "$owner_username" --new-password "$user_pass" >/dev/null
        
        # Grant 'realm-admin' role so they have full control over their realm
        docker exec keycloak-local /opt/keycloak/bin/kcadm.sh add-roles -r "$target_realm" --uusername "$owner_username" --cclientid realm-management --rolename realm-admin >/dev/null
        
        log_info "User '$owner_username' created. They can manage apps at /admin/$target_realm/console/"
    else
        log_info "User '$owner_username' already exists in realm '$target_realm'."
    fi

    # 3. Create the Client (App) in the target realm
    log_info "Creating Keycloak client '$service_name' in realm '$target_realm'..."
    local client_exists=$(docker exec keycloak-local /opt/keycloak/bin/kcadm.sh get clients -r "$target_realm" -q clientId="$service_name" | jq -e '.[0] // empty' || true)
    
    if [ -z "$client_exists" ] || [ "$client_exists" = "null" ]; then
        docker exec keycloak-local /opt/keycloak/bin/kcadm.sh create clients -r "$target_realm" \
            -s clientId="$service_name" \
            -s secret="$password" \
            -s publicClient=false \
            -s directAccessGrantsEnabled=true \
            -s serviceAccountsEnabled=true >/dev/null
        log_info "Created client '$service_name'."
    else
        log_info "Client '$service_name' already exists. Updating secret..."
        local client_id=$(docker exec keycloak-local /opt/keycloak/bin/kcadm.sh get clients -r "$target_realm" -q clientId="$service_name" | jq -r '.[0].id')
        docker exec keycloak-local /opt/keycloak/bin/kcadm.sh update clients/"$client_id" -r "$target_realm" -s secret="$password" >/dev/null
    fi

    log_info "Keycloak ACL setup for '$service_name' completed."
}
