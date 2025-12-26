#!/usr/bin/env bash
set -e

echo "[INFO] Connecting to Redis Cluster (Interactive Mode)..."
echo "-------------------------------------------------------"
echo "Connected to: redis-node-1:7001"
echo "Cluster Mode: Enabled (-c)"
echo "Type 'exit' to quit."
echo "-------------------------------------------------------"

# Connect using the redis-cli inside the container
# This ensures perfect network compatibility with the cluster
docker exec -it redis-node-1 redis-cli -c -p 7001
