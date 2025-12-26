#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
COMPOSE_FILE="${ROOT_DIR}/infras/redis-local/docker-compose.yml"

echo "[INFO] Stopping redis-local using ${COMPOSE_FILE}..."
docker compose -f "${COMPOSE_FILE}" down
echo "[OK] redis-local stopped."
