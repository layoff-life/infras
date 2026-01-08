#!/usr/bin/env bash
set -e
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# Path to the kafka-topics.sh script
KAFKA_BIN="${ROOT_DIR}/kafka-local/kafka_2.12-3.8.1/bin/kafka-topics.sh"

if [ ! -f "$KAFKA_BIN" ]; then
  echo "Error: $KAFKA_BIN not found."
  echo "Please ensure you have downloaded Kafka binaries locally or use the container execution method."
  exit 1
fi

# Force IPv4 to avoid localhost resolution issues on macOS
export KAFKA_HEAP_OPTS="-Xmx1G -Xms1G"
export KAFKA_OPTS="-Djava.net.preferIPv4Stack=true"

echo "[INFO] Listing topics using local Kafka tools..."
echo "[INFO] Connecting to 127.0.0.1:9092..."

# Connect to the brokers using 127.0.0.1 to avoid localhost resolution ambiguity
$KAFKA_BIN --bootstrap-server 127.0.0.1:9092,127.0.0.1:9093,127.0.0.1:9094 --list
