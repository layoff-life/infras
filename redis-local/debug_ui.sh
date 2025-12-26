#!/usr/bin/env bash
set -e

echo "--- Debugging Redis Insight Connection ---"

# 1. Identify the actual network name used by the main cluster
ACTUAL_NETWORK=$(docker inspect redis-node-1 --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{end}}')
echo "[INFO] Redis Cluster is running on network: '$ACTUAL_NETWORK'"

# 2. Check if Redis Insight is attached to it
INSIGHT_NETWORKS=$(docker inspect redis-insight --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}')
echo "[INFO] Redis Insight is attached to: '$INSIGHT_NETWORKS'"

if [[ "$INSIGHT_NETWORKS" != *"$ACTUAL_NETWORK"* ]]; then
  echo "[ERROR] Network Mismatch!"
  echo "  1. Open docker-compose-ui.yml"
  echo "  2. Change 'name: redis-local_redis-cluster-net' to 'name: $ACTUAL_NETWORK'"
  echo "  3. Run ./ui-down.sh && ./ui-up.sh"
  exit 1
else
  echo "[OK] Redis Insight is on the correct network."
fi

# 3. Test Connectivity
echo "[INFO] Testing connectivity from Redis Insight container to Redis Node 1..."
if docker exec redis-insight getent hosts redis-node-1 > /dev/null; then
  echo "[OK] DNS Resolution works: redis-node-1 found."
else
  echo "[ERROR] DNS Resolution failed. Redis Insight cannot find 'redis-node-1'."
fi

echo ""
echo "--- HOW TO CONNECT IN REDIS INSIGHT UI ---"
echo "1. Host:      redis-node-1  (DO NOT use localhost)"
echo "2. Port:      7001"
echo "3. Name:      Local Cluster"
echo "------------------------------------------"
