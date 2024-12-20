variable "federated_credential_name" {
  type        = string
  description = "Federated credential name"
}

variable "rg_name" {
  type        = string
  description = "The name of the resource group"
}

variable "user_assigned_identity_id" {
  type        = string
  description = "User assigned identity id"
}

variable "subject" {
  type        = string
  description = "Federated credential subject"
}

variable "audience" {
  type        = string
  description = "Federated credential audience"
}

variable "issuer_url" {
  type        = string
  description = "Federated credential issuer url"
}
