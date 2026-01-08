#!/usr/bin/env bash

create_acl() {
    local service_name=$1
    local password=$2
    
    local jaas_file="${ROOT_DIR}/kafka-local/kafka_server_jaas.conf"
    local temp_jaas_file=$(mktemp)

    # Check if file exists
    if [ ! -f "$jaas_file" ]; then
        log_error "Kafka JAAS file not found at $jaas_file"
        exit 1
    fi
    
    # This is a bit tricky with simple bash text processing.
    # We look for the closing "};" of KafkaServer block and insert before it.
    
    if grep -q "user_$service_name=" "$jaas_file"; then
        log_warn "Kafka user '$service_name' seems to already exist in JAAS file. Updating..."
        # Use perl to replace the password, writing to a temp file to avoid inode issues.
        perl -pe "s/user_$service_name=\".*\";/user_$service_name=\"$password\";/" "$jaas_file" > "$temp_jaas_file"
        cat "$temp_jaas_file" > "$jaas_file"
        rm "$temp_jaas_file"
        
    else
        log_info "Adding new Kafka user '$service_name' to JAAS file..."
        # Insert before the last "};"
        local new_line="    user_$service_name=\"$password\";"
        
        # Use perl to add the new user, writing to a temp file to avoid inode issues.
        perl -0777 -pe "s/};\s*$/$new_line\n};/s" "$jaas_file" > "$temp_jaas_file"
        cat "$temp_jaas_file" > "$jaas_file"
        rm "$temp_jaas_file"
    fi
    
    log_info "Kafka user added to configuration."
    log_warn "IMPORTANT: You must RESTART the Kafka service for these user changes to take effect."
    log_warn "Run: cd ${ROOT_DIR}/kafka-local && ./down.sh && ./up.sh"
    
    # ---------------------------------------------------------
    # Provision ACLs
    # ---------------------------------------------------------
    log_info "Provisioning Kafka ACLs for user '$service_name'..."
    
    # Needs admin credentials to create ACLs
    local admin_user
    local admin_pass
    admin_user=$(fetch_secret infras/kafka/sasl username)
    admin_pass=$(fetch_secret infras/kafka/sasl password)

    if [ -z "$admin_user" ] || [ -z "$admin_pass" ]; then
        log_warn "Could not fetch Kafka admin credentials. Skipping ACL creation."
        return
    fi
    
    # Create temp admin properties for SASL
    local admin_props=$(mktemp)
    cat <<EOF > "$admin_props"
security.protocol=SASL_PLAINTEXT
sasl.mechanism=PLAIN
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="$admin_user" password="$admin_pass";
EOF

    # Check for running kafka container
    local container="kafka-1"
    if ! docker ps --format '{{.Names}}' | grep -q "^$container$"; then
         log_warn "Container $container is not running. Cannot provision ACLs yet. Please restart Kafka and run this again if needed."
         rm "$admin_props"
         return
    fi
    
    # Copy admin props to container
    docker cp "$admin_props" "$container":/tmp/admin.properties
    
    # Fix permissions so kafka user can read it
    docker exec -u 0 "$container" chmod 644 /tmp/admin.properties
    
    # Run kafka-acls using the admin properties, connecting to the INTERNAL_CLIENT listener port
    log_info "Granting 'All' on Topic '${service_name}-*'"
    docker exec "$container" kafka-acls --bootstrap-server kafka-1:19095 \
        --command-config /tmp/admin.properties \
        --add --allow-principal "User:$service_name" \
        --operation All --topic "$service_name-" --resource-pattern-type PREFIXED
        
    # Grant All on Group prefixed with service_name
    log_info "Granting 'All' on Group '${service_name}-*'"
    docker exec "$container" kafka-acls --bootstrap-server kafka-1:19095 \
        --command-config /tmp/admin.properties \
        --add --allow-principal "User:$service_name" \
        --operation All --group "$service_name-" --resource-pattern-type PREFIXED
        
    # Cleanup
    rm "$admin_props"
    docker exec -u 0 "$container" rm /tmp/admin.properties
    
    log_info "Kafka ACLs provisioned successfully."
}
