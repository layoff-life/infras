#!/usr/bin/env bash

create_acl() {
    local service_name=$1
    local password=$2
    
    local jaas_file="${ROOT_DIR}/kafka-local/kafka_server_jaas.conf"
    
    # Check if file exists
    if [ ! -f "$jaas_file" ]; then
        log_error "Kafka JAAS file not found at $jaas_file"
        exit 1
    fi
    
    # We need to insert the user into the KafkaServer section.
    # Format:
    # KafkaServer {
    #     ...
    #     user_existing="pass";
    #     user_new="pass";
    # };
    
    # This is a bit tricky with simple bash text processing.
    # We look for the closing "};" of KafkaServer block and insert before it.
    
    if grep -q "user_$service_name=" "$jaas_file"; then
        log_warn "Kafka user '$service_name' seems to already exist in JAAS file. Updating..."
        # sed replace: user_service_name=".*"; -> user_service_name="password";
        # escape password for sed?
        # A simple approach: remove the line and append it again structure-wise?
        # Regex update is better.
        
        # Mac sed is weird, use strings if possible.
        # sed -i '' "s/user_$service_name=\".*\";/user_$service_name=\"$password\";/" "$jaas_file"
        
        # Using perl for safer inplace editing
        perl -i -pe "s/user_$service_name=\".*\";/user_$service_name=\"$password\";/" "$jaas_file"
        
    else
        log_info "Adding new Kafka user '$service_name' to JAAS file..."
        # Insert before the last "};"
        # We assume the file ends with }; or contains it.
        # We will append the user line before the last occurrence of };
        
        local new_line="    user_$service_name=\"$password\";"
        
        # Perl logic: replace "};" with "$new_line\n};" but only once? 
        # Actually standard JAAS might have multiple sections. We need 'KafkaServer' section.
        # But 'up.sh' generates a simple file with just KafkaServer usually?
        # Let's assume the file structure from up.sh
        
        perl -0777 -i -pe "s/};\s*$/$new_line\n};/s" "$jaas_file"
    fi
    
    log_info "Kafka user added to configuration."
    log_warn "IMPORTANT: You must RESTART the Kafka service for changes to take effect."
    log_warn "Run: cd ${ROOT_DIR}/kafka-local && ./down.sh && ./up.sh"
    # Or just docker restart? JAAS is mounted?
    # If JAAS is mounted as volume, restart container might work.
    # If JAAS is copied in build, image rebuild needed (unlikely for local).
    # Typically local setup mounts it.
    log_warn "Alternatively: docker restart kafka-local-container-name"
}
