#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
COMPOSE_FILE="${ROOT_DIR}/infras/redis-local/docker-compose.yml"
DATA_DIR_PREFIX="${ROOT_DIR}/volumes/redis-node-"

echo "[INFO] Stopping redis-local cluster..."
${ROOT_DIR}/infras/redis-local/down.sh

echo "[INFO] Removing data directories..."
rm -rf "${DATA_DIR_PREFIX}"*-data

echo "[INFO] Starting redis-local cluster..."
${ROOT_DIR}/infras/redis-local/up.sh

echo "[OK] Reset complete. Waiting for Redis cluster to be ready..."
sleep 5
docker ps | grep redis
