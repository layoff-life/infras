#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
COMPOSE_FILE="${ROOT_DIR}/infras/mysql-local/docker-compose.yml"

echo "[INFO] Stopping mysql-local using ${COMPOSE_FILE}..."
docker compose -f "${COMPOSE_FILE}" down
echo "[OK] mysql-local stopped."
