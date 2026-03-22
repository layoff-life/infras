#!/bin/bash
# Setup local DNS for MiniKube Ingress
# This script adds entries to /etc/hosts for local access to services

set -e

MINIKUBE_IP=$(minikube ip)
HOSTS_FILE="/etc/hosts"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Setup Local DNS for MiniKube Ingress                      ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "MiniKube IP: $MINIKUBE_IP"
echo ""

# Backup hosts file
echo "→ Backing up $HOSTS_FILE to $HOSTS_FILE.backup..."
sudo cp "$HOSTS_FILE" "$HOSTS_FILE.backup" || true

# Add entries
echo "→ Adding entries to $HOSTS_FILE..."
sudo -- bash -c "cat >> '$HOSTS_FILE' << 'EOF'

# MiniKube Ingress - Local DNS (managed by k8s-local)
$MINIKUBE_IP grafana.local
$MINIKUBE_IP prometheus.local
EOF"

echo ""
echo "✅ Local DNS configured!"
echo ""
echo "You can now access:"
echo "  • Grafana:    http://grafana.local"
echo "  • Prometheus: http://prometheus.local"
echo ""
echo "Default credentials:"
echo "  • Grafana:    admin / admin (prompts to change on first login)"
echo "  • Prometheus: (no authentication)"
echo ""
echo "To remove these entries later, edit $HOSTS_FILE and delete the lines above."
echo ""
