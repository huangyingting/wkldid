output "azure_sql_server_fqdn" {
  value       = module.azure_sql.server_fqdn
  description = "Azure SQL server full qualified domain name"
}

output "azure_sql_database_name" {
  value       = module.azure_sql.database_name
  description = "Azure SQL server database name"
}

output "service_account_namespace" {
  value       = local.namespace
  description = "Namespace of the service account"
}

output "service_account_name" {
  value       = local.serviceaccount
  description = "Name of the service account"
}

output "user_assigned_identity_client_id" {
  value       = module.user_assigned_identity.client_id
  description = "The client ID of the user assigned identity"
}