#!/bin/bash
# PostgreSQL Connection Examples
# Shows how to connect from different locations

cat << 'EOF'
╔════════════════════════════════════════════════════════════╗
║  PostgreSQL Connection Guide                               ║
╚════════════════════════════════════════════════════════════╝

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📍 Scenario 1: From Internal Minikube (Different Namespaces)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Use the internal Kubernetes service DNS:

Service: postgres.infras-postgres.svc.cluster.local:5432

Example from another pod in any namespace:
  kubectl run -it --rm psql-client --image=postgres:17-alpine --restart=Never -- \
    psql -h postgres.infras-postgres.svc.cluster.local -U postgres -d postgres

Or from a running pod:
  kubectl exec -n <namespace> <pod-name> -- \
    psql -h postgres.infras-postgres.svc.cluster.local -U postgres -d postgres

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📍 Scenario 2: From Local Machine (Host → Minikube)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Option A: Port-forward to PostgreSQL (RECOMMENDED)
───────────────────────────────────────────────────
  kubectl port-forward -n infras-postgres svc/postgres 5433:5432

Then connect from local machine:
  psql -h localhost -p 5433 -U postgres -d postgres
  # Or with GUI tools: pgAdmin, DBeaver, TablePlus
  # Host: localhost, Port: 5433, User: postgres, Password: <from Vault>

Option B: Minikube Tunnel (for full K8s DNS)
────────────────────────────────────────────────
  # Start tunnel in one terminal
  minikube tunnel

  # Then use kubectl exec from another terminal
  kubectl exec -n infras-postgres deployment/postgres -- psql -U postgres

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📍 Scenario 3: From Remote/External (Outside Minikube)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Option A: Via SSH Tunnel (SECURE - RECOMMENDED)
────────────────────────────────────────────────
  # From your local machine, create SSH tunnel:
  ssh -L 5433:localhost:5433 user@minikube-server -N

  # Then connect locally:
  psql -h localhost -p 5433 -U postgres -d postgres

Option B: Via NodePort (NOT RECOMMENDED - Security Risk)
──────────────────────────────────────────────────────────
  # First, change Service type to NodePort in service.yaml
  # Then connect using minikube IP:
  MINIKUBE_IP=$(minikube ip)
  psql -h $MINIKUBE_IP -p <NodePort> -U postgres -d postgres

Option C: Via Ingress (Requires setup)
──────────────────────────────────────
  # Would need to configure ingress with SSL
  # PostgreSQL connection over HTTP requires additional setup

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔐 Getting the Password
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

The password is stored in Vault at: infras/postgres/auth

To get it:
  kubectl exec -n infras-vault vault-0 -- vault kv get -field=password infras/postgres/auth

Or view full credentials:
  kubectl exec -n infras-vault vault-0 -- vault kv get infras/postgres/auth

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📝 Connection String Examples
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Internal DNS (from pods):
  postgresql://postgres:password@postgres.infras-postgres.svc.cluster.local:5432/postgres

Port-forward (from local):
  postgresql://postgres:password@localhost:5433/postgres

Python (psycopg2):
  import psycopg2
  conn = psycopg2.connect(
      host="postgres.infras-postgres.svc.cluster.local",
      port=5432,
      database="postgres",
      user="postgres",
      password="<from-vault>"
  )

Node.js (pg):
  const { Client } = require('pg');
  const client = new Client({
      host: 'postgres.infras-postgres.svc.cluster.local',
      port: 5432,
      database: 'postgres',
      user: 'postgres',
      password: '<from-vault>'
  });

Go (lib/pq):
  import "database/sql"
  import _ "github.com/lib/pq"

  db, err := sql.Open("postgres",
      "host=postgres.infras-postgres.svc.cluster.local port=5432 "+
      "user=postgres password=<from-vault> dbname=postgres sslmode=disable")

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF
