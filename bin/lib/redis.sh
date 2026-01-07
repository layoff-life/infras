#!/usr/bin/env bash

create_acl() {
    local service_name=$1
    local password=$2
    
    local acl_file="${ROOT_DIR}/redis-local/users.acl"
    
    # Check if file exists
    if [ ! -f "$acl_file" ]; then
        log_error "Redis ACL file not found at $acl_file"
        exit 1
    fi
    
    # Update ACL file (Insert or Replace)
    # We use awk to handle both cases robustly (grep check can be flaky with whitespace)
    # Permissions:
    # - Keys: Restricted to service_name:* (~$service_name:*)
    # - PubSub: All channels (&*)
    # - Commands: All except dangerous ones (+@all -@dangerous)
    # - Cluster: Allow cluster commands (+cluster) for topology discovery
    
    log_info "Updating Redis ACL for '$service_name'..."
    
    local temp_file=$(mktemp)
    local new_line="user $service_name on >$password ~$service_name:* &* +@all -@dangerous +cluster"
    
    awk -v user="$service_name" -v new_line="$new_line" '
    $2 == user { print new_line; found=1; next }
    { print }
    END { if (!found) print new_line }
    ' "$acl_file" > "$temp_file" && cat "$temp_file" > "$acl_file" && rm "$temp_file"
    
    
    # Reload ACLs
    log_info "Reloading Redis ACLs..."
    
    local admin_pass=$(fetch_secret infras/redis/auth password)
    
    if [ -z "$admin_pass" ]; then
        log_warn "Could not fetch Redis admin password. ACL reload might fail if auth is required."
    fi
    
    # Reload on all redis containers in the project
    local containers=$(docker ps --format "{{.Names}}" | grep "redis")
    
    if [ -z "$containers" ]; then
        log_warn "No running Redis containers found to reload ACLs."
    else
        for container in $containers; do
            log_info "Reloading ACL on $container..."
            # Try with auth if we have pass, else without
            if [ -n "$admin_pass" ]; then
                docker exec "$container" redis-cli -a "$admin_pass" ACL LOAD > /dev/null 2>&1 || true
            else
                docker exec "$container" redis-cli ACL LOAD > /dev/null 2>&1 || true
            fi
        done
    fi
    
    log_info "Redis ACL setup for '$service_name' completed."
}
