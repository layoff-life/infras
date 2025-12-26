#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
COMPOSE_FILE="${ROOT_DIR}/infras/mysql-local/docker-compose.yml"
DATA_DIR="${ROOT_DIR}/volumes/mysql-local-data"

echo "[INFO] Stopping mysql-local..."
docker compose -f "${COMPOSE_FILE}" down

if [ -d "$DATA_DIR" ]; then
    echo "[INFO] Removing data directory: $DATA_DIR"
    rm -rf "$DATA_DIR"
fi

echo "[INFO] Starting mysql-local..."
docker compose -f "${COMPOSE_FILE}" up -d

echo "[OK] Reset complete. Waiting for MySQL to be ready..."
sleep 10
docker ps | grep mysql-local
