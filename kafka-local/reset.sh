#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DATA_DIR_PREFIX="${ROOT_DIR}/volumes/kafka-"

echo "[INFO] Stopping kafka-local cluster..."
${ROOT_DIR}/kafka-local/down.sh

echo "[INFO] Checking for processes hogging ports 9092-9097..."
for PORT in 9092 9093 9094 9095 9096 9097; do
  PID=$(lsof -ti :$PORT || true)
  if [ -n "$PID" ]; then
    echo "[WARN] Found process $PID listening on port $PORT. Killing it..."
    kill -9 $PID
    echo "[OK] Process $PID killed."
  else
    echo "[INFO] Port $PORT is free."
  fi
done

echo "[INFO] Removing data directories..."
rm -rf "${DATA_DIR_PREFIX}"*-data

echo "[INFO] Starting kafka-local cluster..."
${ROOT_DIR}/kafka-local/up.sh

echo "[OK] Reset complete. Waiting for Kafka cluster to be ready..."
sleep 10
docker ps | grep kafka
