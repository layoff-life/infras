#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_FILE="${ROOT_DIR}/vault-local/docker-compose.yml"
DATA_DIR="${ROOT_DIR}/volumes/vault-data"
KEYS_FILE="${ROOT_DIR}/vault_keys.txt"

echo "[INFO] Stopping Vault..."
${ROOT_DIR}/vault-local/down.sh

echo "[INFO] Removing Vault data and keys..."
rm -rf "$DATA_DIR"
rm -f "$KEYS_FILE"
touch "$KEYS_FILE"

echo "[INFO] Starting Vault..."
${ROOT_DIR}/vault-local/up.sh

echo "[OK] Vault started. Initializing and unsealing..."
${ROOT_DIR}/vault-local/init_vault.sh

echo "[SUCCESS] Vault is ready and secrets are stored."
echo "Unseal keys and root token are in: $KEYS_FILE"
