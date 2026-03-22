# Allow full access to infra secrets
path "infras/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Allow listing infra secrets
path "infras" {
  capabilities = ["list"]
}
