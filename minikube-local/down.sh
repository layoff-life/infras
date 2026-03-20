#!/bin/bash

# Get the absolute project root (one level up from minikube-local/)
PROJECT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

# 1. Use the state directory inside volumes/minikube/
export MINIKUBE_HOME="$PROJECT_ROOT/volumes/minikube/state"

echo "Stopping minikube in $MINIKUBE_HOME..."
minikube stop

# 2. Cleanup volume mount processes
MOUNT_SOURCE="$PROJECT_ROOT/volumes/minikube/data"
echo "Killing volume mount process..."
pkill -f "minikube mount $MOUNT_SOURCE:/data" || true

echo "--------------------------------------------------------"
echo "Minikube stopped."
echo "--------------------------------------------------------"
