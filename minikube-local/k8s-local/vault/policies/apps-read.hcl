# Allow read-only access to apps secrets
path "apps/*" {
  capabilities = ["read", "list"]
}

# Allow listing apps secrets
path "apps" {
  capabilities = ["list"]
}
