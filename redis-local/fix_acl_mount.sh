#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"

echo "[INFO] Restarting Redis containers to fix ACL file bind mount..."
"${DIR}/down.sh"
"${DIR}/up.sh"

echo "[INFO] Waiting for Redis to be ready..."
sleep 5

echo "[INFO] Running ACL test..."
"${DIR}/test_redis.sh" springboot_demo
