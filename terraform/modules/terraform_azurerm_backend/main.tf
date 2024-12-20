locals {
  tier             = "Standard"
  replication_type = "LRS"
}

resource "azurerm_storage_account" "account" {
  name                     = var.storage_account_name
  location                 = var.location
  resource_group_name      = var.rg_name
  account_tier             = local.tier
  account_replication_type = local.replication_type
  tags                     = var.tags
}

resource "azurerm_storage_container" "container" {
  for_each              = toset(var.environments)
  name                  = "${var.container_name_prefix}-${each.key}"
  storage_account_name  = azurerm_storage_account.account.name
  container_access_type = "private"
}
