#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
K8S_DIR="${PROJECT_DIR}/k8s"
NAMESPACE="infras-cli"
CONTEXT="${1:-minikube}"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Infras-CLI Kubernetes Deploy Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed. Please install kubectl and try again.${NC}"
    exit 1
fi

# Check if minikube is running
if ! minikube status > /dev/null 2>&1; then
    echo -e "${RED}Error: Minikube is not running. Please start minikube and try again.${NC}"
    exit 1
fi

# Set kubectl context
echo -e "${YELLOW}Setting kubectl context to: ${CONTEXT}${NC}"
kubectl config use-context "${CONTEXT}"

echo ""
echo -e "${YELLOW}Applying Kubernetes manifests...${NC}"
echo ""

# Check if k8s directory exists
if [ ! -d "$K8S_DIR" ]; then
    echo -e "${RED}Error: Kubernetes manifests directory not found: ${K8S_DIR}${NC}"
    exit 1
fi

# Apply manifests in order
echo -e "${BLUE}[1/8]${NC} Creating namespace..."
kubectl apply -f "${K8S_DIR}/00-namespace.yaml"

echo -e "${BLUE}[2/8]${NC} Creating service account and RBAC..."
kubectl apply -f "${K8S_DIR}/serviceaccount.yaml"

echo -e "${BLUE}[3/8]${NC} Creating config map..."
kubectl apply -f "${K8S_DIR}/configmap.yaml"

echo -e "${BLUE}[4/8]${NC} Creating resource quota..."
kubectl apply -f "${K8S_DIR}/resourcequota.yaml"

echo -e "${BLUE}[5/8]${NC} Creating network policy..."
kubectl apply -f "${K8S_DIR}/networkpolicy.yaml"

echo -e "${BLUE}[6/8]${NC} Creating deployment..."
kubectl apply -f "${K8S_DIR}/deployment.yaml"

echo -e "${BLUE}[7/8]${NC} Creating service..."
kubectl apply -f "${K8S_DIR}/service.yaml"

echo -e "${BLUE}[8/8]${NC} Creating ingress..."
kubectl apply -f "${K8S_DIR}/ingress.yaml"

echo ""
echo -e "${YELLOW}Waiting for deployment to be ready...${NC}"

# Wait for deployment to be ready
kubectl rollout status deployment/infras-cli -n "${NAMESPACE}" --timeout=120s

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Get pod information
POD_NAME=$(kubectl get pods -n "${NAMESPACE}" -l app=infras-cli -o jsonpath='{.items[0].metadata.name}')

echo -e "Pod: ${GREEN}${POD_NAME}${NC}"
echo ""
echo -e "Service Endpoints:"
echo -e "  API:        ${GREEN}http://infras-cli.local:8080${NC}"
echo -e "  Docs:       ${GREEN}http://infras-cli.local:8080/docs${NC}"
echo -e "  Health:     ${GREEN}http://infras-cli.local:8080/api/v1/health/ready${NC}"
echo -e "  Redoc:      ${GREEN}http://infras-cli.local:8080/redoc${NC}"
echo -e "  OpenAPI:    ${GREEN}http://infras-cli.local:8080/openapi.json${NC}"
echo ""
echo -e "Useful commands:"
echo -e "  View logs:     ${GREEN}kubectl logs -f deployment/infras-cli -n ${NAMESPACE}${NC}"
echo -e "  Check pods:    ${GREEN}kubectl get pods -n ${NAMESPACE}${NC}"
echo -e "  Exec into pod: ${GREEN}kubectl exec -it ${POD_NAME} -n ${NAMESPACE} -- bash${NC}"
echo -e "  Restart:       ${GREEN}kubectl rollout restart deployment/infras-cli -n ${NAMESPACE}${NC}"
echo ""
