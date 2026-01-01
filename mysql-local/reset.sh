#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DATA_DIR="${ROOT_DIR}/volumes/mysql-local-data"

echo "[INFO] Stopping mysql-local..."
${ROOT_DIR}/mysql-local/down.sh

if [ -d "$DATA_DIR" ]; then
    echo "[INFO] Removing data directory: $DATA_DIR"
    rm -rf "$DATA_DIR"
fi

echo "[INFO] Starting mysql-local..."
${ROOT_DIR}/mysql-local/up.sh

echo "[OK] Reset complete. Waiting for MySQL to be ready..."
sleep 10
docker ps | grep mysql-local
