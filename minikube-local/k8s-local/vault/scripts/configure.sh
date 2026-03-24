#!/bin/bash
# Configure Vault with secrets engines and auth methods
# Can be re-run safely

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$VAULT_DIR/../.vault-init"
ROOT_TOKEN_FILE="$OUTPUT_DIR/root-token.txt"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Configure Vault                                           ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check if root token exists
if [ ! -f "$ROOT_TOKEN_FILE" ]; then
    echo "❌ Root token not found!"
    echo "   Initialize Vault first:"
    echo "   $SCRIPT_DIR/init.sh"
    exit 1
fi

ROOT_TOKEN=$(cat "$ROOT_TOKEN_FILE")

# Check if Vault pod is running
POD_NAME=$(kubectl get pods -n infras-vault -l app=vault -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

if [ -z "$POD_NAME" ]; then
    echo "❌ Vault pod not found!"
    exit 1
fi

echo "→ Found Vault pod: $POD_NAME"
echo ""

# Check if Vault is unsealed
echo "→ Checking if Vault is unsealed..."
SEALED=$(kubectl exec -n infras-vault "$POD_NAME" -- env VAULT_TOKEN="$ROOT_TOKEN" vault status -format=json 2>/dev/null | jq -r '.sealed' 2>/dev/null || echo "true")

if [ "$SEALED" = "true" ]; then
    echo "❌ Vault is sealed!"
    echo "   Unseal Vault first:"
    echo "   $SCRIPT_DIR/unseal.sh"
    exit 1
fi

echo "✅ Vault is unsealed"
echo ""

# Helper function to run vault commands inside pod
vault_cmd() {
    kubectl exec -n infras-vault "$POD_NAME" -- env VAULT_TOKEN="$ROOT_TOKEN" vault "$@"
}

echo "════════════════════════════════════════════════════════════"
echo "  Configuring Vault"
echo "════════════════════════════════════════════════════════════"
echo ""

# Enable KV v2 secrets engine for infras
echo "→ Enabling KV v2 secrets engine: infras..."
if vault_cmd secrets list -format=json 2>/dev/null | jq -e '.["infras/"]' &>/dev/null; then
    echo "  ⚠️  Already enabled"
else
    vault_cmd secrets enable -path=infras kv-v2 2>/dev/null || true
    echo "  ✅ Enabled"
fi

# Enable KV v2 secrets engine for apps
echo "→ Enabling KV v2 secrets engine: apps..."
if vault_cmd secrets list -format=json 2>/dev/null | jq -e '.["apps/"]' &>/dev/null; then
    echo "  ⚠️  Already enabled"
else
    vault_cmd secrets enable -path=apps kv-v2 2>/dev/null || true
    echo "  ✅ Enabled"
fi

# Enable userpass auth method
echo "→ Enabling userpass auth method..."
if vault_cmd auth list -format=json 2>/dev/null | jq -e '.["userpass/"]' &>/dev/null; then
    echo "  ⚠️  Already enabled"
else
    vault_cmd auth enable userpass 2>/dev/null || true
    echo "  ✅ Enabled"
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  Creating initial policies"
echo "════════════════════════════════════════════════════════════"
echo ""

POLICY_DIR="$(dirname "$SCRIPT_DIR")/policies"

# Create admin policy (full access including policy management)
echo "→ Creating policy: admin..."
kubectl cp "$POLICY_DIR/admin.hcl" "$POD_NAME:/tmp/admin.hcl" -n infras-vault
vault_cmd policy write admin /tmp/admin.hcl
echo "  ✅ Created"

# Create infras-admin policy
echo "→ Creating policy: infras-admin..."
kubectl cp "$POLICY_DIR/infras-admin.hcl" "$POD_NAME:/tmp/infras-admin.hcl" -n infras-vault
vault_cmd policy write infras-admin /tmp/infras-admin.hcl
echo "  ✅ Created"

# Create apps-read policy
echo "→ Creating policy: apps-read..."
kubectl cp "$POLICY_DIR/apps-read.hcl" "$POD_NAME:/tmp/apps-read.hcl" -n infras-vault
vault_cmd policy write apps-read /tmp/apps-read.hcl
echo "  ✅ Created"

# Create apps-admin policy
echo "→ Creating policy: apps-admin..."
kubectl cp "$POLICY_DIR/apps-admin.hcl" "$POD_NAME:/tmp/apps-admin.hcl" -n infras-vault
vault_cmd policy write apps-admin /tmp/apps-admin.hcl
echo "  ✅ Created"

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  Creating admin user"
echo "════════════════════════════════════════════════════════════"
echo ""

# Function to generate strong random password (20 chars, alphanumeric)
generate_password() {
    # Use subshell to disable pipefail locally because head closes pipe causing SIGPIPE in tr
    (
        set +o pipefail
        LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 20
    )
}

# Create admin user with random password
ADMIN_PASS_FILE="$OUTPUT_DIR/admin-credentials.txt"
echo "→ Creating admin user: admin..."
if vault_cmd read auth/userpass/users/admin 2>/dev/null; then
    echo "  ⚠️  User already exists"
    if [ -f "$ADMIN_PASS_FILE" ]; then
        echo "  Credentials saved in: $ADMIN_PASS_FILE"
    fi
else
    # Generate secure random password
    ADMIN_PASSWORD=$(generate_password)
    vault_cmd write auth/userpass/users/admin password="$ADMIN_PASSWORD" policies="admin"

    # Save credentials to file
    cat > "$ADMIN_PASS_FILE" <<EOF
VAULT ADMIN CREDENTIALS
======================
Username: admin
Password: $ADMIN_PASSWORD

Vault UI Access:
- Cloudflare Tunnel: https://vault.yourdomain.com
- SSH Tunnel: http://vault.local:8080

Created: $(date)
EOF
    chmod 600 "$ADMIN_PASS_FILE"

    echo "  ✅ User created with secure random password"
    echo ""
    echo "  Credentials saved to: $ADMIN_PASS_FILE"
    echo "  Username: admin"
    echo "  Password: $ADMIN_PASSWORD"
    echo ""
    echo "  ⚠️  STORE THIS PASSWORD SECURELY!"
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  Creating Kubernetes Secret for root token"
echo "════════════════════════════════════════════════════════════"
echo ""

# Create secret for root token (used by init containers)
echo "→ Creating secret: vault-root-token..."
if kubectl get secret vault-root-token -n infras-vault &>/dev/null; then
    kubectl delete secret vault-root-token -n infras-vault
fi

kubectl create secret generic vault-root-token \
    --from-literal=token="$ROOT_TOKEN" \
    -n infras-vault

echo "  ✅ Secret created"
echo ""
echo "  ⚠️  This secret contains the root token!"
echo "     Only grant access to trusted service accounts!"
echo ""

echo "════════════════════════════════════════════════════════════"
echo "  Vault Configuration Complete!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Secrets Engines:"
echo "  • infras/  (KV v2) - Infrastructure secrets"
echo "  • apps/    (KV v2) - Application secrets"
echo ""
echo "Auth Methods:"
echo "  • userpass - Username/password authentication"
echo ""
echo "Policies:"
echo "  • admin         - Full administrative access (including policy management)"
echo "  • infras-admin  - Full access to infras/"
echo "  • apps-admin    - Full access to apps/"
echo "  • apps-read     - Read-only access to apps/"
echo ""
echo "Users:"
echo "  • admin (policies: admin)"
echo "    Password saved in: $ADMIN_PASS_FILE"
echo ""
echo "════════════════════════════════════════════════════════════"
echo "  Access Vault UI"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Via Cloudflare Tunnel:"
echo "  https://vault.yourdomain.com"
echo ""
echo "Via SSH Tunnel:"
echo "  ssh -L 8080:localhost:8080 user@server -N"
echo "  http://vault.local:8080"
echo ""
echo "Login with:"
echo "  • Token: $ROOT_TOKEN"
echo "  • Username: admin (see password in $ADMIN_PASS_FILE)"
echo ""
echo "════════════════════════════════════════════════════════════"
echo ""
