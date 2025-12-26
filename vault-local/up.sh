#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
COMPOSE_FILE="${ROOT_DIR}/infras/vault-local/docker-compose.yml"

echo "[INFO] Starting Vault using ${COMPOSE_FILE}..."
docker compose -f "${COMPOSE_FILE}" up -d
echo "[OK] Vault is starting at http://localhost:8200"
echo "     Root Token: root"
