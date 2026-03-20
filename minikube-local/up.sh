#!/bin/bash

# Get the absolute project root (one level up from minikube-local/)
PROJECT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

# 1. Use the state directory inside volumes/minikube/
export MINIKUBE_HOME="$PROJECT_ROOT/volumes/minikube/state"

echo "Starting minikube in $MINIKUBE_HOME..."
minikube start \
  --cpus=8 \
  --memory=16384mb \
  --disk-size=50g \
  --driver=docker

# 2. Automatically mount the data directory inside volumes/minikube/
MOUNT_SOURCE="$PROJECT_ROOT/volumes/minikube/data"
echo "Mounting $MOUNT_SOURCE to /data inside minikube (background)..."

# Check if a mount is already running and kill it if so
pkill -f "minikube mount $MOUNT_SOURCE:/data" || true

nohup minikube mount "$MOUNT_SOURCE:/data" > "$MINIKUBE_HOME/mount.log" 2>&1 &
MOUNT_PID=$!

echo "--------------------------------------------------------"
echo "Minikube is up! Resources: 8 CPUs, 16GiB RAM"
echo "State location: $MINIKUBE_HOME"
echo "Volume mount: $MOUNT_SOURCE -> /data (PID: $MOUNT_PID)"
echo "Logs for the mount: tail -f $MINIKUBE_HOME/mount.log"
echo "--------------------------------------------------------"
