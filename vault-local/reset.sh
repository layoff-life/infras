#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_FILE="${ROOT_DIR}/vault/docker-compose.yml"
DATA_DIR="${ROOT_DIR}/volumes/vault-data"
KEYS_FILE="${ROOT_DIR}/vault_keys.txt"

echo "[INFO] Stopping Vault..."
docker compose -f "${COMPOSE_FILE}" down

echo "[INFO] Removing Vault data and keys..."
rm -rf "$DATA_DIR"
rm -f "$KEYS_FILE"
touch "$KEYS_FILE"

echo "[INFO] Starting Vault..."
docker compose -f "${COMPOSE_FILE}" up -d

echo "[OK] Vault started. Initializing and unsealing..."
./init_vault.sh

echo "[SUCCESS] Vault is ready and secrets are stored."
echo "Unseal keys and root token are in: $KEYS_FILE"
