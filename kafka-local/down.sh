#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
COMPOSE_FILE="${ROOT_DIR}/infras/kafka-local/docker-compose.yml"

echo "[INFO] Stopping kafka-local using ${COMPOSE_FILE}..."
docker compose -f "${COMPOSE_FILE}" down
echo "[OK] kafka-local stopped."
