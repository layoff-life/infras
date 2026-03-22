# Vault - Secret Management

HashiCorp Vault deployment for secure secrets management in MiniKube cluster.

---

## 📁 Directory Structure

```
vault/
├── policies/                    # Vault policy HCL files
│   ├── admin.hcl               # Full admin policy
│   ├── infras-admin.hcl        # Infrastructure secrets admin
│   ├── apps-admin.hcl          # Application secrets admin
│   └── apps-read.hcl           # Application read-only policy
├── scripts/                     # Management scripts
│   ├── deploy.sh               # Deploy Vault to cluster
│   ├── init.sh                 # Initialize Vault
│   ├── unseal.sh               # Unseal Vault
│   └── configure.sh            # Configure Vault (secrets, auth, policies)
├── .vault-init/                 # Sensitive initialization files (gitignored)
│   ├── cluster-keys.json       # Unseal keys
│   ├── root-token.txt          # Root token
│   └── admin-credentials.txt   # Admin credentials
├── configmap.yaml               # Vault configuration
├── ingress.yaml                 # Ingress route
├── serviceaccount.yaml          # RBAC
├── service.yaml                 # Services (ClusterIP, NodePort, Headless)
├── statefulset.yaml            # Vault StatefulSet
└── README.md                   # This file
```

---

## 🚀 Quick Start

### 1. Deploy Vault

```bash
./scripts/deploy.sh
```

### 2. Initialize Vault

```bash
./scripts/init.sh
```

This generates unseal keys and root token in `.vault-init/`

### 3. Unseal Vault (run 3 times)

```bash
./scripts/unseal.sh
./scripts/unseal.sh
./scripts/unseal.sh
```

### 4. Configure Vault

```bash
./scripts/configure.sh
```

This sets up:
- KV v2 secrets engines (`infras/`, `apps/`)
- `userpass` auth method
- Policies (admin, infras-admin, apps-admin, apps-read)
- Admin user with secure random password

---

## 🔐 Credentials

**Admin credentials** are stored in `.vault-init/admin-credentials.txt`:

```bash
cat .vault-init/admin-credentials.txt
```

⚠️ **BACKUP THIS DIRECTORY SECURELY!**

---

## 📊 Access Vault UI

### Via Cloudflare Tunnel

Configure in Cloudflare Dashboard:

| Field | Value |
|-------|-------|
| Subdomain | `vault` |
| Service | `http://localhost:8080` |
| Host Header | `vault.local` |

Access: **https://vault.yourdomain.com**

### Via SSH Tunnel

```bash
# On local machine
ssh -L 8080:localhost:8080 user@server -N

# Add to /etc/hosts
sudo bash -c 'echo "127.0.0.1 vault.local" >> /etc/hosts'
```

Access: **http://vault.local:8080**

### Login Options

1. **Token**: Use root token from `.vault-init/root-token.txt`
2. **UserPass**: Username/password from `.vault-init/admin-credentials.txt`

---

## 📝 Policies

| Policy | Description | Path |
|--------|-------------|------|
| `admin` | Full admin access to all Vault | `policies/admin.hcl` |
| `infras-admin` | Full access to `infras/` secrets | `policies/infras-admin.hcl` |
| `apps-admin` | Full access to `apps/` secrets | `policies/apps-admin.hcl` |
| `apps-read` | Read-only access to `apps/` secrets | `policies/apps-read.hcl` |

---

## 🔧 Management Scripts

All scripts are in `scripts/` directory and can be re-run safely.

### deploy.sh
Deploys Vault to the cluster (updates if exists).

```bash
./scripts/deploy.sh
```

### init.sh
Initializes Vault (checks if already initialized).

```bash
./scripts/init.sh
```

### unseal.sh
Unseals Vault using saved keys (checks if already unsealed).

```bash
./scripts/unseal.sh
```

### configure.sh
Configures secrets engines, auth methods, and policies (idempotent).

```bash
./scripts/configure.sh
```

---

## 🛠️ Troubleshooting

### Vault Pod Not Ready

The pod may show 0/1 Ready but Vault is actually working. Check status:

```bash
kubectl exec -n infras-vault vault-0 -- vault status
```

### Cannot Initialize

```bash
# Check if already initialized
kubectl exec -n infras-vault vault-0 -- vault status -format=json | jq -r '.initialized'

# Re-initialize (wipes data!)
kubectl exec -n infras-vault vault-0 -- rm -rf /vault/file/*
kubectl delete pod vault-0 -n infras-vault
./scripts/init.sh
```

### Cannot Unseal

```bash
# Check seal status
kubectl exec -n infras-vault vault-0 -- vault status

# Unseal manually
kubectl exec -n infras-vault vault-0 -- vault operator unseal <KEY>
```

### Lost Unseal Keys

If you lose the keys in `.vault-init/cluster-keys.json`, you cannot recover your Vault data. You'll need to:

1. Backup any data you need
2. Delete the PVC: `kubectl delete pvc vault-data-vault-0 -n infras-vault`
3. Restart: `./scripts/deploy.sh && ./scripts/init.sh`

---

## 🔒 Security Best Practices

1. **Backup .vault-init/** - Store securely (password manager, HSM)
2. **Change default password** - Update admin user password
3. **Rotate root token** - After initial setup
4. **Use policies** - Grant minimal permissions
5. **Enable audit logs** - For production
6. **Token TTL** - Set appropriate lease durations

---

## 📚 Additional Resources

- [Vault Documentation](https://developer.hashicorp.com/vault/docs)
- [Vault Kubernetes Integration](https://developer.hashicorp.com/vault/docs/platform/k8s)
- [Policy Syntax](https://developer.hashicorp.com/vault/docs/concepts/policies)

---

## ⚡ Quick Commands Reference

```bash
# Deployment
./scripts/deploy.sh

# Initialize
./scripts/init.sh

# Unseal (run 3x)
./scripts/unseal.sh

# Configure
./scripts/configure.sh

# Check status
kubectl exec -n infras-vault vault-0 -- vault status

# View logs
kubectl logs -n infras-vault -l app=vault -f

# Access UI
# Cloudflare: https://vault.yourdomain.com
# SSH: http://vault.local:8080
```
