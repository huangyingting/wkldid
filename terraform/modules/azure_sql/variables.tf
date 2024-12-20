variable "azure_sql_server_name" {
  description = "Azure SQL server name"
  type        = string
}

variable "azure_sql_database_name" {
  description = "Azure SQL database name"
  type        = string
}

variable "location" {
  description = "The location of the Azure SQL server"
  type        = string
}

variable "rg_name" {
  description = "The name of the resource group in which the Azure SQL server will be created"
  type        = string
}

variable "outbound_ip" {
  description = "Outbound IP address to be whitelisted from Azure SQL firewall."
  type        = string
}

variable "tags" {
  description = "A mapping of tags to assign to the Azure SQL server"
  type        = map(string)
}
