#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KEYS_FILE="${ROOT_DIR}/vault_keys.txt"
COMPOSE_FILE="${ROOT_DIR}/kafka-local/docker-compose.yml"
JAAS_FILE="${ROOT_DIR}/kafka-local/kafka_server_jaas.conf"

# Function to fetch secret from Vault
fetch_secret() {
    local path=$1
    local field=$2
    if [ -n "${VAULT_TOKEN:-}" ]; then
        docker exec -e VAULT_TOKEN="$VAULT_TOKEN" vault-local vault kv get -mount=secret -field="$field" "$path"
    else
        docker exec vault-local vault kv get -mount=secret -field="$field" "$path"
    fi
}

# Check if Vault is running and keys exist
if [ -f "$KEYS_FILE" ] && [ "$(docker ps -q -f name=vault-local)" ]; then
    echo "[INFO] Vault detected. Fetching secrets..."
    
    # Get Root Token
    export VAULT_TOKEN=$(jq -r ".root_token" "$KEYS_FILE")
    
    # Fetch Secrets
    KAFKA_SASL_USER=$(fetch_secret kafka/sasl username)
    KAFKA_SASL_PASS=$(fetch_secret kafka/sasl password)
    
    echo "[INFO] Generating Kafka JAAS configuration..."
    cat <<EOF > "$JAAS_FILE"
KafkaServer {
    org.apache.kafka.common.security.plain.PlainLoginModule required
    username="$KAFKA_SASL_USER"
    password="$KAFKA_SASL_PASS"
    user_$KAFKA_SASL_USER="$KAFKA_SASL_PASS";
};
EOF
    echo "[INFO] Secrets fetched and JAAS config generated."
else
    echo "[WARN] Vault not detected or keys missing. Using existing configuration."
fi

echo "[INFO] Starting kafka-local using ${COMPOSE_FILE}..."
docker compose -f "${COMPOSE_FILE}" up -d
echo "[OK] kafka-local is starting. Use 'docker ps' to verify the container."
