variable "storage_account_name" {
  type        = string
  description = "The name of the storage account"
}

variable "location" {
  type        = string
  description = "The location of storage account"
}

variable "rg_name" {
  type        = string
  description = "The name of the resource group"
}

variable "environments" {
  type        = list(string)
  description = "The environments to create"
}

variable "container_name_prefix" {
  type        = string
  description = "The prefix name of storage container"
}

variable "tags" {
  type        = map(string)
  description = "A mapping of tags to assign to the resource"
}
