locals {
  default_audience  = "api://AzureADTokenExchange"
  github_issuer_url = "https://token.actions.githubusercontent.com"
}

data "azurerm_subscription" "subscription" {
}

module "resource_group" {
  source   = "../modules/resource_group"
  name     = var.rg_name
  location = var.location
  tags     = var.tags
}

module "terraform_azurerm_backend" {
  source                = "../modules/terraform_azurerm_backend"
  storage_account_name  = var.storage_account_name
  rg_name               = module.resource_group.name
  location              = var.location
  tags                  = var.tags
  environments          = var.environments
  container_name_prefix = var.container_name_prefix
}

module "user_assigned_identity" {
  source   = "../modules/user_assigned_identity"
  name     = var.gh_uai_name
  location = var.location
  rg_name  = module.resource_group.name
  tags     = var.tags
}

module "azurerm_backend_role_assignment" {
  source       = "../modules/role_assignment"
  principal_id = module.user_assigned_identity.principal_id
  role_name    = "Storage Blob Data Contributor"
  scope_id     = module.terraform_azurerm_backend.id
}

module "subscription_role_assignment" {
  source       = "../modules/role_assignment"
  principal_id = module.user_assigned_identity.principal_id
  role_name    = "Contributor"
  scope_id     = data.azurerm_subscription.subscription.id
}

module "github_pr_federated_credential" {
  source                    = "../modules/federated_credential"
  federated_credential_name = "${var.github_organization}-${var.github_repository}-pr"
  rg_name                   = module.resource_group.name
  user_assigned_identity_id = module.user_assigned_identity.id
  subject                   = "repo:${var.github_organization}/${var.github_repository}:pull_request"
  audience                  = local.default_audience
  issuer_url                = local.github_issuer_url
}

module "github_env_federated_credential" {
  for_each                  = toset(var.environments)
  source                    = "../modules/federated_credential"
  federated_credential_name = "${var.github_organization}-${var.github_repository}-${each.key}"
  rg_name                   = module.resource_group.name
  user_assigned_identity_id = module.user_assigned_identity.id
  subject                   = "repo:${var.github_organization}/${var.github_repository}:environment:${each.key}"
  audience                  = local.default_audience
  issuer_url                = local.github_issuer_url
}

module "github_environment" {
  for_each                     = toset(var.environments)
  source                       = "../modules/github_environment"
  environment                  = each.key
  github_organization          = var.github_organization
  github_repository            = var.github_repository
  azure_client_id              = module.user_assigned_identity.client_id
  azure_subscription_id        = data.azurerm_subscription.subscription.subscription_id
  azure_tenant_id              = data.azurerm_subscription.subscription.tenant_id
  tfstate_resource_group_name  = module.resource_group.name
  tfstate_storage_account_name = module.terraform_azurerm_backend.storage_account_name
  tfstate_container_name       = "${var.container_name_prefix}-${each.key}"
  resource_prefix              = var.resource_prefix
  location                     = var.location
}

module "entra_id_role_assignment" {
  source       = "../modules/entra_id_role_assignment"
  role_name    = "Privileged Role Administrator"
  principal_id = module.user_assigned_identity.principal_id
}
