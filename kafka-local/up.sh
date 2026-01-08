#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KEYS_FILE="${ROOT_DIR}/vault_keys.txt"
COMPOSE_FILE="${ROOT_DIR}/kafka-local/docker-compose.yml"
JAAS_FILE="${ROOT_DIR}/kafka-local/kafka_server_jaas.conf"

# Source Common Library
source "${ROOT_DIR}/bin/lib/common.sh"

echo "[INFO] Starting kafka-local..."

# Only (re)generate JAAS file if it doesn't already exist to preserve any
# credentials that may have been added later by bin/lib/kafka.sh
if [ -f "$JAAS_FILE" ]; then
    echo "[INFO] Existing JAAS file found at $JAAS_FILE — preserving credentials (no overwrite)."
else
    # Check Vault Availability
    check_vault
    if [ -n "${VAULT_TOKEN:-}" ]; then
        echo "[INFO] Vault detected. Ensuring/Fetching secrets..."

        # Ensure credential exists
        ensure_credential "infras/kafka/sasl" "admin"

        # Fetch Secrets
        export KAFKA_SASL_USERNAME=$(fetch_secret infras/kafka/sasl username)
        export KAFKA_SASL_PASSWORD=$(fetch_secret infras/kafka/sasl password)

        echo "[INFO] Secrets fetched successfully."

        # Generate Broker Credentials
        JAAS_CONTENT="KafkaServer {
        org.apache.kafka.common.security.plain.PlainLoginModule required
        username=\"$KAFKA_SASL_USERNAME\"
        password=\"$KAFKA_SASL_PASSWORD\"
        user_$KAFKA_SASL_USERNAME=\"$KAFKA_SASL_PASSWORD\""

        for i in 1 2 3; do
            broker="kafka-$i"
            ensure_credential "infras/kafka/$broker" "$broker"
            pass=$(fetch_secret "infras/kafka/$broker" password)

            # Export for docker-compose
            export KAFKA_${i}_PASSWORD="$pass"

            # Append to JAAS (use broker name with hyphen to match configured usernames)
            JAAS_CONTENT="${JAAS_CONTENT}
        user_${broker}=\"$pass\""
        done

        # Close JAAS
        JAAS_CONTENT="${JAAS_CONTENT}
        ;
    };"
    else
        echo "[WARN] Vault not detected or keys missing. Using existing configuration."
    fi
    echo "[INFO] Generating Kafka JAAS configuration..."
    echo "$JAAS_CONTENT" > "$JAAS_FILE"
    echo "[INFO] Secrets fetched and JAAS config generated."
fi


# Migrate legacy underscore-based broker usernames in JAAS to hyphenated form if present
if [ -f "$JAAS_FILE" ]; then
    if grep -qE 'user_kafka_1=|user_kafka_2=|user_kafka_3=' "$JAAS_FILE"; then
        echo "[INFO] Migrating broker usernames in JAAS from underscores to hyphens (user_kafka_1 -> user_kafka-1, etc.)"
        tmpfile=$(mktemp)
        perl -pe 's/user_kafka_1=/user_kafka-1=/g; s/user_kafka_2=/user_kafka-2=/g; s/user_kafka_3=/user_kafka-3=/g;' "$JAAS_FILE" > "$tmpfile"
        cat "$tmpfile" > "$JAAS_FILE"
        rm -f "$tmpfile"
        echo "[INFO] JAAS migration complete."
    fi
fi


# Always export broker passwords for docker-compose, regardless of whether JAAS was regenerated
check_vault || true
if [ -n "${VAULT_TOKEN:-}" ]; then
    for i in 1 2 3; do
        broker="kafka-$i"
        ensure_credential "infras/kafka/$broker" "$broker"
        pass=$(fetch_secret "infras/kafka/$broker" password)
        export KAFKA_${i}_PASSWORD="$pass"
    done
else
    # Fallback: parse existing JAAS file to export passwords so controller auth can succeed
    if [ -f "$JAAS_FILE" ]; then
        echo "[INFO] Vault not detected. Exporting broker passwords from existing JAAS file."
        for i in 1 2 3; do
            pass=""
            if grep -q "user_kafka-$i=\"" "$JAAS_FILE"; then
                pass=$(grep "user_kafka-$i=\"" "$JAAS_FILE" | tail -n1 | sed -E 's/.*user_kafka-[0-9]+=\"([^\"]+)\".*/\1/')
            elif grep -q "user_kafka_$i=\"" "$JAAS_FILE"; then
                pass=$(grep "user_kafka_$i=\"" "$JAAS_FILE" | tail -n1 | sed -E 's/.*user_kafka_[0-9]+=\"([^\"]+)\".*/\1/')
            fi
            if [ -n "$pass" ]; then
                export KAFKA_${i}_PASSWORD="$pass"
            else
                echo "[WARN] Could not find password for kafka-$i in JAAS file to export as KAFKA_${i}_PASSWORD."
            fi
        done
    else
        echo "[WARN] Vault not detected or keys missing — cannot export broker passwords. Ensure KAFKA_1/2/3_PASSWORD are set in your environment before running docker compose."
    fi
fi


# Export a static CLUSTER_ID
export CLUSTER_ID='MkU3OEVBNTcwNTJENDM2Qk'

echo "[INFO] Starting kafka-local using ${COMPOSE_FILE}..."
docker compose -f "${COMPOSE_FILE}" up -d
echo "[OK] kafka-local is starting. Use 'docker ps' to verify the container."
