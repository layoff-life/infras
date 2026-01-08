#!/usr/bin/env bash
set -e

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# Path to the kafka-topics.sh script
KAFKA_BIN="${ROOT_DIR}/kafka-local/kafka_2.12-3.8.1/bin/kafka-topics.sh"

if [ ! -f "$KAFKA_BIN" ]; then
  echo "Error: $KAFKA_BIN not found. Please ensure you are in the kafka-local directory."
  exit 1
fi

# Force IPv4 to avoid localhost resolution issues on macOS
# Increase Heap to handle potential client-side overhead
export KAFKA_HEAP_OPTS="-Xmx1G -Xms1G"
export KAFKA_OPTS="-Djava.net.preferIPv4Stack=true"

echo "[INFO] Listing topics using local Kafka tools with SASL..."
# Connect to any of the brokers in the cluster using SASL ports
$KAFKA_BIN --bootstrap-server 127.0.0.1:9095,127.0.0.1:9096,127.0.0.1:9097 --list --command-config ${ROOT_DIR}/kafka-local/client_sasl.properties
