#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
# Fix to correct bin dir path: SCRIPT_DIR is .../tests, ROOT is .../infras. BIN is .../infras/bin
BIN_DIR="${ROOT_DIR}/bin"

TEST_APP="test_app_$(date +%s)"

log() { echo "[VERIFY] $1"; }

# 1. Setup MySQL
log "Setting up MySQL for $TEST_APP..."
# Capture output to file to preserve logs while extracting token
${BIN_DIR}/setup_acl.sh "$TEST_APP" mysql > setup_mysql.log 2>&1
cat setup_mysql.log

TOKEN_1=$(grep "TOKEN:" setup_mysql.log | awk '{print $2}')
log "Token 1: $TOKEN_1"

if [ -z "$TOKEN_1" ]; then
    log "Failed to extract token."
    exit 1
fi

# Debug Capabilities
log "Checking capabilities for Token 1 on infras/mysql/$TEST_APP..."
docker exec -e VAULT_TOKEN="$(jq -r ".root_token" "$ROOT_DIR/vault_keys.txt")" vault-local vault token capabilities -format=json "$TOKEN_1" "infras/mysql/$TEST_APP"

# 2. Verify Token 1 can read MySQL secret
log "Verifying Token 1 access to MySQL secret..."
if docker exec -e VAULT_TOKEN="$TOKEN_1" vault-local vault kv get -mount=infras "mysql/$TEST_APP" | grep -q "username"; then
    log "SUCCESS: Found 'username' field in secret."
else
    log "FAILURE: 'username' field MISSING or Token 1 CANNOT read 'infras/mysql/$TEST_APP'"
    exit 1
fi

# 3. Setup Redis (Add service to existing app)
log "Setting up Redis for $TEST_APP..."
${BIN_DIR}/setup_acl.sh "$TEST_APP" redis > setup_redis.log 2>&1
cat setup_redis.log

# Extract Token 2 (Should act same as Token 1 permissions-wise)
TOKEN_2=$(grep "TOKEN:" setup_redis.log | awk '{print $2}')
log "Token 2: $TOKEN_2"

# 4. Verify Token 1 can read Redis secret
log "Verifying Token 1 access to Redis secret..."
if docker exec -e VAULT_TOKEN="$TOKEN_1" vault-local vault kv get -mount=infras "redis/$TEST_APP"; then
    log "SUCCESS: Token 1 can read 'infras/redis/$TEST_APP'"
else
    log "FAILURE: Token 1 CANNOT read 'infras/redis/$TEST_APP'"
fi

log "Verification Complete."
