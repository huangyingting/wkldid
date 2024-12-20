variable "aks_name" {
  description = "The name of the AKS cluster"
  type        = string
}

variable "location" {
  description = "The location of the AKS cluster"
  type        = string
}

variable "rg_name" {
  description = "The name of the resource group"
  type        = string
}

variable "node_count" {
  description = "The number of nodes in the AKS cluster"
  type        = number
}

variable "vm_size" {
  description = "The size of the Virtual Machine"
  type        = string
}

variable "tags" {
  description = "A mapping of tags to assign to the AKS cluster."
  type        = map(string)
}
