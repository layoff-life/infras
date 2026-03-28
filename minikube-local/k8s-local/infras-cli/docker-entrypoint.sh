#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Infras-CLI API Container Entrypoint${NC}"
echo ""

# Skip auto-fetch if VAULT_TOKEN is already set
if [ -n "$VAULT_TOKEN" ]; then
    echo -e "${GREEN}✓${NC} VAULT_TOKEN already set (from environment)"
else
    echo -e "${YELLOW}→${NC} VAULT_TOKEN not set, attempting to fetch from Kubernetes secret..."

    # Try to fetch Vault token from Kubernetes secret
    # The service account should have permissions to read this secret
    if KUBE_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token 2>/dev/null); then
        KUBE_CERT=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

        # Try to fetch the Vault root token from the infras-vault namespace
        VAULT_SECRET_BASE64=$(kubectl get secret vault-root-token \
            -n infras-vault \
            --token="$KUBE_TOKEN" \
            --certificate-authority="$KUBE_CERT" \
            -o jsonpath='{.data.token}' 2>/dev/null || echo "")

        if [ -n "$VAULT_SECRET_BASE64" ]; then
            # Decode base64 token
            VAULT_TOKEN=$(echo "$VAULT_SECRET_BASE64" | base64 -d 2>/dev/null || echo "")

            if [ -n "$VAULT_TOKEN" ]; then
                export VAULT_TOKEN
                echo -e "${GREEN}✓${NC} Successfully fetched Vault token from Kubernetes secret"
            else
                echo -e "${RED}✗${NC} Failed to decode Vault token"
            fi
        else
            echo -e "${YELLOW}⚠${NC} Could not fetch Vault token from Kubernetes secret"
            echo -e "${YELLOW}→${NC} The application will start but Vault operations will fail"
            echo -e "${YELLOW}→${NC} Ensure the secret 'vault-root-token' exists in namespace 'infras-vault'"
        fi
    else
        echo -e "${RED}✗${NC} Not running in Kubernetes or cannot access service account token"
    fi
fi

# Display configuration
echo ""
echo -e "${GREEN}Configuration:${NC}"
echo -e "  VAULT_ADDR:    ${VAULT_ADDR:-not set}"
echo -e "  VAULT_TOKEN:   ${VAULT_TOKEN:+[hidden]}${VAULT_TOKEN:-not set}"
echo -e "  LOG_LEVEL:     ${LOG_LEVEL:-INFO}"
echo ""

# Verify kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}✗${NC} kubectl not found in PATH"
    exit 1
fi

echo -e "${GREEN}✓${NC} kubectl version: $(kubectl version --client --short 2>/dev/null || echo 'unknown')"

# Verify Python can import required modules
echo -e "${GREEN}✓${NC} Python version: $(python --version 2>&1)"

# Start the application
echo ""
echo -e "${GREEN}Starting Infras-CLI API...${NC}"
echo ""

# Execute the main command
# If arguments are provided, use them (allows overriding defaults)
if [ $# -gt 0 ]; then
    exec "$@"
else
    exec python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
fi
