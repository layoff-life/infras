#!/usr/bin/env bash
set -e

echo "[INFO] Checking ACL inside redis-node-1..."
docker exec redis-node-1 cat /usr/local/etc/redis/users.acl

echo ""
echo "[INFO] Checking loaded ACLs via redis-cli..."
# Try to connect with default user
# We use explicit --user and --pass to be reliable
docker exec redis-node-1 redis-cli -p 7001 --user default --pass 3KGdb7AIH4FHBUu3 --no-auth-warning ACL LIST
