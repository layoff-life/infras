#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DATA_DIR="${ROOT_DIR}/volumes/postgres-data"

${ROOT_DIR}/postgres-local/down.sh
rm -rf "$DATA_DIR"
${ROOT_DIR}/postgres-local/up.sh
