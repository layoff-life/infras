# Allow full access to apps secrets
path "apps/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Allow listing apps secrets
path "apps" {
  capabilities = ["list"]
}
