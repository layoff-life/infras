#!/usr/bin/env bash
set -e

echo "[INFO] Checking /etc/hosts for Redis Cluster mappings..."

REQUIRED_ENTRY="127.0.0.1 redis-node-1 redis-node-2 redis-node-3"

if grep -q "redis-node-1" /etc/hosts; then
    echo "[OK] /etc/hosts already contains redis-node mappings."
    echo "     Ensure it looks like this: $REQUIRED_ENTRY"
else
    echo "[ERROR] IntelliJ/JDBC cannot resolve the internal Docker hostnames."
    echo "---------------------------------------------------------------------"
    echo "To fix this, you must add the following line to your /etc/hosts file:"
    echo ""
    echo "$REQUIRED_ENTRY"
    echo ""
    echo "Run this command to add it automatically (requires sudo):"
    echo "sudo sh -c 'echo \"$REQUIRED_ENTRY\" >> /etc/hosts'"
    echo "---------------------------------------------------------------------"
    exit 1
fi
