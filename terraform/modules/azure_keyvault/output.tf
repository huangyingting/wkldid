output "vault_uri" {
  value = azurerm_key_vault.kv.vault_uri
}

output "secret_name" {
  value = azurerm_key_vault_secret.secret.name
}