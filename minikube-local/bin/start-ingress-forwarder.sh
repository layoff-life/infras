#!/bin/bash
# Start MiniKube Ingress Port Forwarder
# Forwards host:8080 to minikube NodePort:30559 (Ingress Controller)

set -e

echo "→ Starting MiniKube Ingress Port Forwarder..."

# Get minikube details
MINIKUBE_IP=$(minikube ip)
MINIKUBE_NETWORK=$(docker inspect minikube -f '{{range .NetworkSettings.Networks}}{{.NetworkID}}{{end}}')

if [ -z "$MINIKUBE_IP" ] || [ -z "$MINIKUBE_NETWORK" ]; then
    echo "❌ Failed to get MiniKube details. Is minikube running?"
    exit 1
fi

# Remove existing container if present
docker stop minikube-ingress-forwarder 2>/dev/null || true
docker rm minikube-ingress-forwarder 2>/dev/null || true

# Start new forwarder
docker run -d \
    --name minikube-ingress-forwarder \
    --network "$MINIKUBE_NETWORK" \
    -p 8080:8080 \
    --restart unless-stopped \
    alpine/socat \
    TCP-LISTEN:8080,fork,reuseaddr TCP:${MINIKUBE_IP}:30559

echo "✅ Ingress forwarder started on port 8080"
echo ""
echo "Check status: docker ps | grep minikube-ingress-forwarder"
echo "View logs: docker logs minikube-ingress-forwarder"
