#!/usr/bin/env bash
set -e

echo "[INFO] Testing Redis Cluster SET/GET..."

# Key and Value to test
KEY="test_key_$(date +%s)"
VALUE="Hello_Redis_Cluster"

echo "[INFO] Setting Key: $KEY = $VALUE"
# Use -c for cluster mode to follow redirects automatically
docker exec redis-node-1 redis-cli -p 7001 -c SET "$KEY" "$VALUE"

echo "[INFO] Getting Key: $KEY"
RESULT=$(docker exec redis-node-1 redis-cli -p 7001 -c GET "$KEY")

echo "[INFO] Result: $RESULT"

if [ "$RESULT" == "$VALUE" ]; then
  echo "[SUCCESS] Redis Cluster SET/GET working correctly."
else
  echo "[ERROR] Value mismatch! Expected: $VALUE, Got: $RESULT"
  exit 1
fi
