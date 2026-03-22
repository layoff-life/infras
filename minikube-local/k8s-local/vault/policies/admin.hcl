# Full admin policy - grants access to all operations
# This policy provides complete administrative access to Vault

# Allow all operations on all paths
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# System health checks
path "sys/health" {
  capabilities = ["read", "sudo"]
}

# Full access to all secrets engines
path "secret/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Full access to infras secrets
path "infras/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Full access to apps secrets
path "apps/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Audit log access
path "sys/audit" {
  capabilities = ["read", "list"]
}

# Auth method management
path "auth/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Policy management
path "sys/policies/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
