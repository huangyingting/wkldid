data "azurerm_client_config" "current" {}

data "azuread_service_principal" "current" {
  object_id = data.azurerm_client_config.current.object_id
}

resource "azurerm_mssql_server" "server" {
  name                = var.azure_sql_server_name
  resource_group_name = var.rg_name
  location            = var.location
  version             = "12.0"
  azuread_administrator {
    login_username              = data.azuread_service_principal.current.display_name
    object_id                   = data.azurerm_client_config.current.object_id
    azuread_authentication_only = true
  }
  identity {
    type = "SystemAssigned"
  }
  tags = var.tags
}

module "entra_id_role_assignment" {
  source       = "../entra_id_role_assignment"
  role_name    = "Directory Readers"
  principal_id = azurerm_mssql_server.server.identity[0].principal_id
}

resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  name             = "allow_azure_services"
  server_id        = azurerm_mssql_server.server.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_mssql_firewall_rule" "allow_ips" {
  name             = "allow_ips"
  server_id        = azurerm_mssql_server.server.id
  start_ip_address = var.outbound_ip
  end_ip_address   = var.outbound_ip
}

resource "azurerm_mssql_database" "database" {
  name                        = var.azure_sql_database_name
  server_id                   = azurerm_mssql_server.server.id
  collation                   = "SQL_Latin1_General_CP1_CI_AS"
  sample_name                 = "AdventureWorksLT"
  auto_pause_delay_in_minutes = 60
  max_size_gb                 = 32
  min_capacity                = 0.5
  sku_name                    = "GP_S_Gen5_1"
  storage_account_type        = "Local"
  tags                        = var.tags
}
