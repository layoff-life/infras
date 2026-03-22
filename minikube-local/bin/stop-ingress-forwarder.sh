#!/bin/bash
# Stop MiniKube Ingress Port Forwarder

echo "→ Stopping MiniKube Ingress Port Forwarder..."

docker stop minikube-ingress-forwarder 2>/dev/null || true
docker rm minikube-ingress-forwarder 2>/dev/null || true

echo "✅ Ingress forwarder stopped"
