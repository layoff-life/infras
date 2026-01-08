#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"

echo "[INFO] Restarting Kafka containers to fix ACL file bind mount..."
"${DIR}/down.sh"
"${DIR}/up.sh"

echo "[INFO] Waiting for Kafka to be ready..."
sleep 5

echo "[INFO] Finish."
