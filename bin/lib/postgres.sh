#!/usr/bin/env bash

create_acl() {
    local service_name=$1
    local password=$2
    
    # Fetch Admin Credentials
    log_info "Fetching Postgres admin credentials..."
    # 'postgres' is usually the superuser
    local admin_user="postgres"
    local admin_pass=$(fetch_secret infras/postgres/auth password)
    
    # Note: PGPASSWORD environment variable is used by psql
    
    if [ -z "$admin_pass" ]; then
        log_error "Failed to fetch Postgres admin password from Vault."
        exit 1
    fi

    log_info "Creating Postgres user and database for '$service_name'..."

    # Check if user exists
    local user_exists=$(docker exec -e PGPASSWORD="$admin_pass" postgres-local psql -U "$admin_user" -tAc "SELECT 1 FROM pg_roles WHERE rolname='$service_name'")
    
    if [ "$user_exists" != "1" ]; then
        log_info "User '$service_name' does not exist. Creating..."
        if ! docker exec -e PGPASSWORD="$admin_pass" postgres-local psql -U "$admin_user" -c "CREATE USER \"$service_name\" WITH PASSWORD '$password';"; then
            log_error "Failed to create Postgres user."
            exit 1
        fi
    else
        log_info "User '$service_name' exists. Updating password..."
        if ! docker exec -e PGPASSWORD="$admin_pass" postgres-local psql -U "$admin_user" -c "ALTER USER \"$service_name\" WITH PASSWORD '$password';"; then
            log_error "Failed to update Postgres user password."
            exit 1
        fi
    fi

    # Check if database exists
    local db_exists=$(docker exec -e PGPASSWORD="$admin_pass" postgres-local psql -U "$admin_user" -tAc "SELECT 1 FROM pg_database WHERE datname='$service_name'")

    if [ "$db_exists" != "1" ]; then
        log_info "Database '$service_name' does not exist. Creating..."
        if ! docker exec -e PGPASSWORD="$admin_pass" postgres-local psql -U "$admin_user" -c "CREATE DATABASE \"$service_name\" OWNER \"$service_name\";"; then
            log_error "Failed to create Postgres database."
            exit 1
        fi
    else
        log_info "Database '$service_name' already exists."
        # Ensure ownership/permissions
        if ! docker exec -e PGPASSWORD="$admin_pass" postgres-local psql -U "$admin_user" -c "ALTER DATABASE \"$service_name\" OWNER TO \"$service_name\";"; then
            log_warn "Failed to update database ownership (non-fatal)."
        fi
    fi
    
    log_info "Postgres setup for '$service_name' completed."
}
