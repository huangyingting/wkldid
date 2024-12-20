data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv" {
  name                       = var.kv_name
  location                   = var.location
  resource_group_name        = var.rg_name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  sku_name                   = "standard"
  enable_rbac_authorization  = true
}

module "secret_officer_role_assignment" {
  source       = "../role_assignment"
  principal_id = data.azurerm_client_config.current.object_id
  role_name    = "Key Vault Secrets Officer"
  scope_id     = azurerm_key_vault.kv.id
}

resource "azurerm_key_vault_secret" "secret" {
  name         = "secret"
  value        = "Azure workload identity secret"
  key_vault_id = azurerm_key_vault.kv.id
}

module "secret_user_role_assignment" {
  source       = "../role_assignment"
  principal_id = var.principal_id
  role_name    = "Key Vault Secrets User"
  scope_id     = azurerm_key_vault.kv.id
}
