variable "environment" {
  type        = string
  description = "Github deployment environment name"
}

variable "github_organization" {
  type        = string
  description = "Github organization name"
}

variable "github_repository" {
  type        = string
  description = "Github repository name"
}

variable "azure_client_id" {
  type        = string
  description = "Azure client id (user assigned managed identity)"
}

variable "azure_subscription_id" {
  type        = string
  description = "Azure subscription id"
}

variable "azure_tenant_id" {
  type        = string
  description = "Azure tenant id"
}

variable "tfstate_resource_group_name" {
  type        = string
  description = "Terraform state resource group name"
}

variable "tfstate_storage_account_name" {
  type        = string
  description = "Terraform state storage account name"
}

variable "tfstate_container_name" {
  type        = string
  description = "Terraform state container name"
}

variable "resource_name" {
  type        = string
  description = "Resource name"
}

variable "location" {
  type        = string
  description = "Resource deployed location"
}
