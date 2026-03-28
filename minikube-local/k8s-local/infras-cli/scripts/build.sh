#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
IMAGE_NAME="infras-cli"
IMAGE_TAG="${1:-latest}"
FULL_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Infras-CLI Docker Build Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not running. Please start Docker and try again.${NC}"
    exit 1
fi

# Check if minikube is running
if ! minikube status > /dev/null 2>&1; then
    echo -e "${RED}Error: Minikube is not running. Please start minikube and try again.${NC}"
    exit 1
fi

echo -e "${YELLOW}Building Docker image: ${FULL_IMAGE}${NC}"
echo ""

# Change to project directory
cd "$PROJECT_DIR"

# Get kubectl binary - use host's kubectl if available, otherwise download
if [ ! -f "kubectl" ]; then
    if command -v kubectl &> /dev/null; then
        echo -e "${YELLOW}Using host kubectl binary...${NC}"
        cp /usr/local/bin/kubectl ./kubectl
        chmod +x kubectl
        echo -e "${GREEN}✓${NC} Copied kubectl from host"
    else
        echo -e "${YELLOW}kubectl not found on host, downloading...${NC}"
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        chmod +x kubectl
        echo -e "${GREEN}✓${NC} Downloaded kubectl"
    fi
fi

# Build Docker image using host network for connectivity
docker build --network=host -t "${FULL_IMAGE}" .

echo ""
echo -e "${YELLOW}Loading image into minikube registry...${NC}"

# Load image into minikube
minikube image load "${FULL_IMAGE}"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Build Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Image: ${GREEN}${FULL_IMAGE}${NC}"
echo -e "Available in minikube registry"
echo ""
echo -e "Next steps:"
echo -e "  1. Deploy to Kubernetes: ${GREEN}./scripts/deploy.sh${NC}"
echo -e "  2. Check pod status:     ${GREEN}kubectl get pods -n infras-cli${NC}"
echo -e "  3. View logs:           ${GREEN}kubectl logs -f deployment/infras-cli -n infras-cli${NC}"
echo ""
