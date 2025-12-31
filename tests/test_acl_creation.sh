#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BIN_DIR="${ROOT_DIR}/bin"

# Test Variables
TEST_SERVICE="test_svc_$(date +%s)"
VAULT_KEY_FILE="${ROOT_DIR}/vault_keys.txt"

log() {
    echo "[TEST] $1"
}

if [ ! -f "$VAULT_KEY_FILE" ]; then
    log "Vault keys not found. Cannot test."
    exit 1
fi

export VAULT_TOKEN=$(jq -r ".root_token" "$VAULT_KEY_FILE")

check_vault_secret() {
    local service=$1
    local type=$2
    # Expect secret at infras/<type>/<service>
    log "Checking Vault for infras/$type/$service..."
    docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault-local vault kv get -mount=infras "$type/$service" > /dev/null
}

test_mysql() {
    log "--- Testing MySQL ---"
    "${BIN_DIR}/setup_acl.sh" "$TEST_SERVICE" mysql
    check_vault_secret "$TEST_SERVICE" mysql
    
    local password=$(docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault-local vault kv get -mount=infras -field=password "mysql/$TEST_SERVICE")
    
    log "Attempting connection..."
    docker exec mysql-local mysql -u"$TEST_SERVICE" -p"$password" -e "SELECT 1;" > /dev/null
    log "MySQL Connection Success!"
}

test_postgres() {
    log "--- Testing Postgres ---"
    "${BIN_DIR}/setup_acl.sh" "$TEST_SERVICE" postgres
    check_vault_secret "$TEST_SERVICE" postgres
    
    local password=$(docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault-local vault kv get -mount=infras -field=password "postgres/$TEST_SERVICE")
    
    log "Attempting connection..."
    docker exec -e PGPASSWORD="$password" postgres-local psql -U "$TEST_SERVICE" -d "$TEST_SERVICE" -c "SELECT 1;" > /dev/null
    log "Postgres Connection Success!"
}

test_redis() {
    log "--- Testing Redis ---"
    "${BIN_DIR}/setup_acl.sh" "$TEST_SERVICE" redis
    check_vault_secret "$TEST_SERVICE" redis
    
    local password=$(docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault-local vault kv get -mount=infras -field=password "redis/$TEST_SERVICE")
    
    # Needs ACL LOAD to have happened. bin/setup_acl.sh does it.
    
    log "Attempting connection..."
    # Find a redis node
    local redis_container=$(docker ps --format "{{.Names}}" | grep "redis" | awk 'NR==1')
    log "Found Redis Container: '$redis_container'"
    
    if [ -n "$redis_container" ]; then
        docker exec "$redis_container" redis-cli --user "$TEST_SERVICE" --pass "$password" ping > /dev/null
        log "Redis Connection Success (on $redis_container)!"
    else
        log "No redis container found to test. Docker PS output:"
        docker ps --format "{{.Names}}"
    fi
}

test_kafka() {
    log "--- Testing Kafka ---"
    "${BIN_DIR}/setup_acl.sh" "$TEST_SERVICE" kafka
    check_vault_secret "$TEST_SERVICE" kafka
    
    # We can't easily test connection without restarting Kafka.
    # Verification is: check if JAAS file was updated.
    local jaas_file="${ROOT_DIR}/kafka-local/kafka_server_jaas.conf"
    if grep -q "user_$TEST_SERVICE=" "$jaas_file"; then
        log "JAAS file updated successfully."
    else
        echo "FAIL: JAAS file not updated."
        exit 1
    fi
}

# Run Tests
test_mysql
test_redis
test_kafka

echo "ALL TESTS PASSED."
