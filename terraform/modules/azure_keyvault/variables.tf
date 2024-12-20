variable "location" {
  description = "The location of the key vault"
  type        = string
}

variable "rg_name" {
  description = "The name of the resource group in which the key vault will be created"
  type        = string
}

variable "kv_name" {
  description = "The name of the key vault"
  type        = string
}

variable "principal_id" {
  description = "The principal id of the user assigned managed identity"
  type        = string  
}