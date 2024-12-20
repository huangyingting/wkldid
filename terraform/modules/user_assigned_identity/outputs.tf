output "id" {
  value = azurerm_user_assigned_identity.msi.id
  description = "The ID of the user assigned identity"
}

output "client_id" {
  value = azurerm_user_assigned_identity.msi.client_id
  description = "The ID of the app associated with the identity."
}

output "principal_id" {
  value = azurerm_user_assigned_identity.msi.principal_id
  description = "The ID of the service principal object associated with the created identity"
}