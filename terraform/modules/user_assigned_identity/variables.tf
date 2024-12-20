variable "location" {
  type        = string
  description = "The location where the user-assigned managed identity will be created"
}

variable "name" {
  type        = string
  description = "The name of the user-assigned managed identity"
}

variable "rg_name" {
  type        = string
  description = "The name of the resource group"
}

variable "tags" {
  type        = map(string)
  description = "A mapping of tags to assign to the resource"
}
