# PostgreSQL Connection Guide

Complete guide for connecting to PostgreSQL from different locations.

---

## 📍 Scenario 1: Internal Minikube (Different Namespaces)

**Use Case:** Application pods in Kubernetes connecting to PostgreSQL

**Connection Details:**
- **Host:** `postgres.infras-postgres.svc.cluster.local`
- **Port:** `5432`
- **Database:** `postgres`
- **User:** `postgres`
- **Password:** Get from Vault (see below)

**Connection String:**
```
postgresql://postgres:<password>@postgres.infras-postgres.svc.cluster.local:5432/postgres
```

**Test Connection:**
```bash
# From any pod in any namespace
kubectl exec -n <namespace> <pod-name> -- \
  psql -h postgres.infras-postgres.svc.cluster.local -U postgres -d postgres

# Or create a temporary client pod
kubectl run -it --rm psql-client --image=postgres:17-alpine --restart=Never -- \
  psql -h postgres.infras-postgres.svc.cluster.local -U postgres -d postgres
```

---

## 📍 Scenario 2: From Local Machine (Host → Minikube)

**Use Case:** Development from your local machine

### Option A: Port-Forward (RECOMMENDED)

**Step 1:** Start port-forward (in one terminal):
```bash
kubectl port-forward -n infras-postgres svc/postgres 5433:5432
```

**Step 2:** Get password:
```bash
kubectl exec -n infras-vault vault-0 -- vault kv get -field=password infras/postgres/auth
```

**Step 3:** Connect from local machine:
```bash
# Command line
psql -h localhost -p 5433 -U postgres -d postgres

# Or with GUI tools
# pgAdmin, DBeaver, TablePlus, etc.
# Host: localhost
# Port: 5433
# User: postgres
# Password: <from step 2>
```

**Connection String:**
```
postgresql://postgres:<password>@localhost:5433/postgres
```

### Option B: Kubectl Exec (Quick & Dirty)

```bash
# Direct access via kubectl
kubectl exec -n infras-postgres deployment/postgres -- psql -U postgres
```

---

## 📍 Scenario 3: From Remote/External (Outside Minikube)

**Use Case:** Production access or remote development

### Option A: SSH Tunnel (SECURE - RECOMMENDED)

**Step 1:** Create SSH tunnel from your local machine:
```bash
ssh -L 5433:localhost:5433 user@minikube-server -N
```

**Step 2:** Connect locally (tunnel forwards to minikube):
```bash
psql -h localhost -p 5433 -U postgres -d postgres
```

### Option B: Cloudflare Tunnel (Alternative)

If using Cloudflare Tunnel for ingress, expose PostgreSQL service.

⚠️ **Warning:** Only use SSL/TLS connections for external access!

### Option C: NodePort (NOT RECOMMENDED)

⚠️ **Security Risk:** Exposes database directly to network

1. Change service type to NodePort in `service.yaml`
2. Get minikube IP: `minikube ip`
3. Connect: `psql -h $MINIKUBE_IP -p <NodePort> -U postgres`

---

## 🔐 Getting Credentials

### From Vault

**View full credentials:**
```bash
kubectl exec -n infras-vault vault-0 -- vault kv get infras/postgres/auth
```

**Get only password:**
```bash
kubectl exec -n infra-vault vault-0 -- vault kv get -field=password infras/postgres/auth
```

**Get only username:**
```bash
kubectl exec -n infras-vault vault-0 -- vault kv get -field=username infras/postgres/auth
```

---

## 📝 Language-Specific Examples

### Python (psycopg2)
```python
import psycopg2

conn = psycopg2.connect(
    host="postgres.infras-postgres.svc.cluster.local",
    port=5432,
    database="postgres",
    user="postgres",
    password="<from-vault>"
)
```

### Node.js (pg)
```javascript
const { Client } = require('pg');

const client = new Client({
    host: 'postgres.infras-postgres.svc.cluster.local',
    port: 5432,
    database: 'postgres',
    user: 'postgres',
    password: '<from-vault>'
});

await client.connect();
```

### Go (lib/pq)
```go
import (
    "database/sql"
    _ "github.com/lib/pq"
)

db, err := sql.Open("postgres",
    "host=postgres.infras-postgres.svc.cluster.local "+
    "port=5432 "+
    "user=postgres "+
    "password=<from-vault> "+
    "dbname=postgres "+
    "sslmode=disable")
```

### Java (JDBC)
```java
String url = "jdbc:postgresql://postgres.infras-postgres.svc.cluster.local:5432/postgres";
Properties props = new Properties();
props.setProperty("user", "postgres");
props.setProperty("password", "<from-vault>");
Connection conn = DriverManager.getConnection(url, props);
```

### Ruby (pg)
```ruby
require 'pg'

conn = PG.connect(
    host: 'postgres.infras-postgres.svc.cluster.local',
    port: 5432,
    dbname: 'postgres',
    user: 'postgres',
    password: '<from-vault>'
)
```

---

## 🧪 Quick Test Commands

```bash
# Test from postgres pod
kubectl exec -n infras-postgres deployment/postgres -- psql -U postgres -c "SELECT version();"

# Test from vault namespace (cross-namespace)
kubectl exec -n infras-vault vault-0 -- sh -c 'nc -zv postgres.infras-postgres.svc.cluster.local 5432'

# Test configuration
kubectl exec -n infras-postgres deployment/postgres -- psql -U postgres -c "SHOW max_connections;"

# View metrics
kubectl port-forward -n infras-postgres svc/postgres-exporter 9187:9187
curl http://localhost:9187/metrics
```

---

## 🛠️ Troubleshooting

### Connection Refused
```bash
# Check pod status
kubectl get pods -n infras-postgres

# Check service exists
kubectl get svc -n infras-postgres

# Test DNS from another namespace
kubectl run -it --rm dns-test --image=busybox --restart=Never -- \
  nslookup postgres.infras-postgres.svc.cluster.local
```

### Authentication Failed
```bash
# Get current password from Vault
kubectl exec -n infra-vault vault-0 -- vault kv get infras/postgres/auth

# Check if pod is using correct secret
kubectl get pod -n infras-postgres -o yaml | grep -A 10 "postgres-password"
```

### Port-Forward Not Working
```bash
# Check if service exists
kubectl get svc -n infras-postgres postgres

# Check service endpoints
kubectl get endpoints -n infras-postgres postgres

# Try specific pod port-forward instead
kubectl port-forward -n infras-postgres pod/<postgres-pod-name> 5433:5432
```

---

## 📊 Monitoring

### View Logs
```bash
# PostgreSQL logs
kubectl logs -n infras-postgres -f -l app=postgres -c postgres

# Exporter logs
kubectl logs -n infras-postgres -f -l app=postgres -c exporter
```

### Check Metrics
```bash
# Port-forward to access metrics
kubectl port-forward -n infras-postgres svc/postgres-exporter 9187:9187

# View metrics in browser
curl http://localhost:9187/metrics | grep pg_up
```

---

## 🔒 Security Best Practices

1. **Never expose PostgreSQL directly** without SSL/TLS
2. **Use Vault for credentials** - don't hardcode passwords
3. **Limit access** with NetworkPolicies
4. **Rotate passwords** regularly via Vault
5. **Use read-only users** for applications when possible
6. **Enable SSL** for external connections
7. **Monitor connections** via logs and metrics

---

## 📚 Related Files

- `deployment.yaml` - PostgreSQL deployment manifest
- `service.yaml` - Service definitions
- `scripts/deploy.sh` - Deployment script with Vault integration
- `scripts/connect-examples.sh` - This guide
