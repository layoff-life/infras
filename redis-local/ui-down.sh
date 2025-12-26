#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
COMPOSE_FILE="${ROOT_DIR}/infras/redis-local/docker-compose-ui.yml"

echo "[INFO] Stopping Redis Insight..."
docker compose -f "${COMPOSE_FILE}" down
echo "[OK] Redis Insight stopped."
