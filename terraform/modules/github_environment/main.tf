data "github_user" "current" {
  username = ""
}

data "github_repository" "repository" {
  full_name = "${var.github_organization}/${var.github_repository}"
}

resource "github_repository_environment" "environment" {
  environment = var.environment
  repository  = data.github_repository.repository.name
  reviewers {
    users = [data.github_user.current.id]
  }
  deployment_branch_policy {
    protected_branches     = true
    custom_branch_policies = false
  }
}

resource "github_actions_environment_secret" "azure_client_id" {
  repository      = data.github_repository.repository.name
  environment     = github_repository_environment.environment.environment
  secret_name     = "AZURE_CLIENT_ID"
  plaintext_value = var.azure_client_id
}

resource "github_actions_environment_secret" "azure_subscription_id" {
  repository      = data.github_repository.repository.name
  environment     = github_repository_environment.environment.environment
  secret_name     = "AZURE_SUBSCRIPTION_ID"
  plaintext_value = var.azure_subscription_id
}

resource "github_actions_environment_secret" "azure_tenant_id" {
  repository      = data.github_repository.repository.name
  environment     = github_repository_environment.environment.environment
  secret_name     = "AZURE_TENANT_ID"
  plaintext_value = var.azure_tenant_id
}

resource "github_actions_environment_secret" "tfstate_resource_group_name" {
  repository      = data.github_repository.repository.name
  environment     = github_repository_environment.environment.environment
  secret_name     = "TFSTATE_RESOURCE_GROUP_NAME"
  plaintext_value = var.tfstate_resource_group_name
}

resource "github_actions_environment_secret" "tfstate_storage_account_name" {
  repository      = data.github_repository.repository.name
  environment     = github_repository_environment.environment.environment
  secret_name     = "TFSTATE_STORAGE_ACCOUNT_NAME"
  plaintext_value = var.tfstate_storage_account_name
}

resource "github_actions_environment_secret" "tfstate_container_name" {
  repository      = data.github_repository.repository.name
  environment     = github_repository_environment.environment.environment
  secret_name     = "TFSTATE_CONTAINER_NAME"
  plaintext_value = var.tfstate_container_name
}

resource "github_actions_environment_secret" "resource_name" {
  repository      = data.github_repository.repository.name
  environment     = github_repository_environment.environment.environment
  secret_name     = "RESOURCE_NAME"
  plaintext_value = var.resource_name
}

resource "github_actions_environment_secret" "location" {
  repository      = data.github_repository.repository.name
  environment     = github_repository_environment.environment.environment
  secret_name     = "LOCATION"
  plaintext_value = var.location
}