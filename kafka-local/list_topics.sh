#!/usr/bin/env bash
set -e

# Path to the kafka-topics.sh script
KAFKA_BIN="./kafka_2.12-3.8.1/bin/kafka-topics.sh"

if [ ! -f "$KAFKA_BIN" ]; then
  echo "Error: $KAFKA_BIN not found. Please ensure you are in the kafka-local directory."
  exit 1
fi

# Force IPv4 to avoid localhost resolution issues on macOS
# Increase Heap to handle potential client-side overhead
export KAFKA_HEAP_OPTS="-Xmx1G -Xms1G"
export KAFKA_OPTS="-Djava.net.preferIPv4Stack=true"

echo "[INFO] Listing topics using local Kafka tools..."
# Connect to any of the brokers in the cluster
$KAFKA_BIN --bootstrap-server localhost:9092,localhost:9093,localhost:9094 --list
