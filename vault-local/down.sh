#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
COMPOSE_FILE="${ROOT_DIR}/infras/vault-local/docker-compose.yml"

echo "[INFO] Stopping Vault..."
docker compose -f "${COMPOSE_FILE}" down
echo "[OK] Vault stopped."
