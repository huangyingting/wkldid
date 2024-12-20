variable "resource_name" {
  type = string
}

variable "location" {
  type    = string
  default = "southeastasia"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "outbound_ip" {
  type = string
}
