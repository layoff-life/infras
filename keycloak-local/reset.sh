#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_FILE="${ROOT_DIR}/keycloak-local/docker-compose.yml"
DATA_DIR="${ROOT_DIR}/volumes/keycloak-data"

docker compose -f "${COMPOSE_FILE}" down
rm -rf "$DATA_DIR"
"${ROOT_DIR}/keycloak-local/up.sh"
