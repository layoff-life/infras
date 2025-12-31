#!/usr/bin/env bash

create_acl() {
    local service_name=$1
    local password=$2
    
    # Fetch Admin Credentials
    log_info "Fetching MySQL admin credentials..."
    local admin_user="root"
    local admin_pass=$(fetch_secret infras/mysql/root password)
    
    if [ -z "$admin_pass" ]; then
        log_error "Failed to fetch MySQL admin password from Vault."
        exit 1
    fi

    # Create User and Grant Permissions
    log_info "Creating MySQL user '$service_name'..."
    
    # We use 'create user if not exists' to be safe, but we update the password
    # Permissions: We'll grant ALL on a database named after the service
    
    # SQL Commands
    # 1. Create User
    # 2. Create Database (if not exists)
    # 3. Grant Privileges
    
    local sql_cmds="
    CREATE DATABASE IF NOT EXISTS \`${service_name}\`;
    CREATE USER IF NOT EXISTS '${service_name}'@'%' IDENTIFIED BY '${password}';
    ALTER USER '${service_name}'@'%' IDENTIFIED BY '${password}';
    GRANT ALL PRIVILEGES ON \`${service_name}\`.* TO '${service_name}'@'%';
    FLUSH PRIVILEGES;
    "
    
    # Execute via Docker
    # We suppress the warning about password on CLI if possible, but for debugging we need output
    if docker exec mysql-local mysql -u"$admin_user" -p"$admin_pass" -e "$sql_cmds"; then
        log_info "MySQL user '$service_name' created/updated and granted access to database '$service_name'."
    else
        log_error "Failed to create MySQL user. See output above."
        exit 1
    fi
}
