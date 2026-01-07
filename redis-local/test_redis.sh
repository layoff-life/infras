#!/usr/bin/env bash
set -e

USERNAME="${1:-default}"
PASSWORD="${2:-}"
DIR="$(cd "$(dirname "$0")" && pwd)"
ACL_FILE="${DIR}/users.acl"

# Auto-detect password if not provided
if [ -z "$PASSWORD" ] && [ -f "$ACL_FILE" ]; then
    # Look for 'user <username> ... >password ...'
    DETECTED_PASS=$(awk -v user="$USERNAME" '$1=="user" && $2==user { for(i=3;i<=NF;i++) if($i ~ /^>/) print substr($i, 2) }' "$ACL_FILE")
    if [ -n "$DETECTED_PASS" ]; then
        PASSWORD="$DETECTED_PASS"
        echo "[INFO] Auto-detected password for user '$USERNAME' from users.acl"
    else
        echo "[WARN] Password not provided and not found in users.acl for user '$USERNAME'."
    fi
fi

echo "[INFO] Testing Redis Cluster SET/GET for user: $USERNAME..."

# Key and Value to test
if [ "$USERNAME" == "default" ] || [ "$USERNAME" == "worker" ]; then
    KEY="test_key_$(date +%s)"
else
    KEY="${USERNAME}:test_key_$(date +%s)"
fi

VALUE="Hello_Redis_Cluster_User_${USERNAME}"

echo "[INFO] Setting Key: $KEY = $VALUE"

# Execute SET using explicit --user and --pass arguments
# We use --no-auth-warning to suppress the warning about password on CLI
docker exec redis-node-1 redis-cli -p 7001 -c --user "$USERNAME" --pass "$PASSWORD" --no-auth-warning SET "$KEY" "$VALUE"

echo "[INFO] Getting Key: $KEY"
RESULT=$(docker exec redis-node-1 redis-cli -p 7001 -c --user "$USERNAME" --pass "$PASSWORD" --no-auth-warning GET "$KEY")

echo "[INFO] Result: $RESULT"

if [ "$RESULT" == "$VALUE" ]; then
  echo "[SUCCESS] Redis Cluster SET/GET working correctly for user $USERNAME."
else
  echo "[ERROR] Value mismatch! Expected: $VALUE, Got: $RESULT"
  exit 1
fi
