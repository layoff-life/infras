#!/bin/bash
# Simple script to expose metrics to minikube
# Run this whenever you want to update the HOST RESOURCES section in Grafana

METRICS_DIR="/tmp/node_exporter_textfile"
METRICS_FILE="$METRICS_DIR/docker_stats.prom"

echo "Exposing docker stats to minikube..."

if [ ! -f "$METRICS_FILE" ]; then
    echo "❌ Metrics file not found!"
    echo "   Start the collector first:"
    echo "   /home/hunghlh/app/infras/minikube-local/k8s-local/monitoring/host-stats/setup-host-metrics.sh"
    exit 1
fi

# Read metrics
METRICS_CONTENT=$(cat "$METRICS_FILE")

# Method 1: Try minikube cp
echo "Trying minikube cp..."
minikube cp "$METRICS_FILE" /tmp/ 2>/dev/null

# Method 2: Try via ssh with timeout
if [ $? -ne 0 ]; then
    echo "minikube cp failed, trying alternative method..."
    # Write to a temporary file in minikube
    echo "$METRICS_CONTENT" > /tmp/docker-stats-to-expose.prom
    minikube cp /tmp/docker-stats-to-expose.prom /tmp/docker-stats.prom 2>/dev/null
fi

# Move to final location
echo "Moving to node-exporter directory..."
minikube ssh "sudo mkdir -p /tmp/node_exporter_textfile" 2>/dev/null
echo "$METRICS_CONTENT" > /tmp/docker-stats-upload.prom
minikube cp /tmp/docker-stats-upload.prom /tmp/docker-stats.prom 2>/dev/null
minikube ssh "sudo mv /tmp/docker-stats.prom /tmp/node_exporter_textfile/docker_stats.prom" 2>/dev/null

# Verify
sleep 1
RESULT=$(minikube ssh "cat /tmp/node_exporter_textfile/docker_stats.prom 2>/dev/null | grep -c "docker_" || echo "0")

if [ "$RESULT" -gt 0 ]; then
    echo "✅ Metrics exposed to minikube!"
    echo ""
    echo "Metrics will appear in Grafana in 30-60 seconds."
    echo ""
    echo "Current values:"
    minikube ssh "cat /tmp/node_exporter_textfile/docker_stats.prom" | grep docker_cpu_percent
    minikube ssh "cat /tmp/node_exporter_textfile/docker_stats.prom" | grep docker_memory_percent
else
    echo "⚠️  Exposure may have failed. Trying direct method..."
    # Direct write attempt using cp
    echo "$METRICS_CONTENT" > /tmp/docker-stats-fallback.prom
    minikube cp /tmp/docker-stats-fallback.prom /tmp/docker-stats.prom 2>/dev/null
    minikube ssh "sudo mv /tmp/docker-stats.prom /tmp/node_exporter_textfile/docker_stats.prom" 2>/dev/null || true
fi

echo ""
echo "Check Grafana dashboard section '3. HOST RESOURCES' for updated values."
