locals {
  tags = {
    "environment" = var.environment
  }
  node_count       = 1
  vm_size          = "Standard_B2s"
  namespace        = "wkldid"
  default_audience = "api://AzureADTokenExchange"
  serviceaccount   = "sa${var.resource_name}"
}

module "resource_group" {
  source   = "../modules/resource_group"
  name     = var.resource_name
  location = var.location
  tags     = local.tags
}

module "aks" {
  source     = "../modules/aks"
  aks_name   = "aks${var.resource_name}"
  location   = var.location
  rg_name    = module.resource_group.name
  node_count = local.node_count
  vm_size    = local.vm_size
  tags       = local.tags
}

module "user_assigned_identity" {
  source   = "../modules/user_assigned_identity"
  name     = var.resource_name
  location = var.location
  rg_name  = module.resource_group.name
  tags     = local.tags
}

module "aks_federated_credential" {
  source                    = "../modules/federated_credential"
  federated_credential_name = "fedcred"
  rg_name                   = module.resource_group.name
  user_assigned_identity_id = module.user_assigned_identity.id
  subject                   = "system:serviceaccount:${local.namespace}:${local.serviceaccount}"
  audience                  = local.default_audience
  issuer_url                = module.aks.oidc_issuer_url
}

module "azure_sql" {
  source                  = "../modules/azure_sql"
  azure_sql_server_name   = "sql${var.resource_name}"
  azure_sql_database_name = var.resource_name
  location                = var.location
  rg_name                 = module.resource_group.name
  outbound_ip             = var.outbound_ip
  tags                    = local.tags
}

# resource "null_resource" "run_sql_script" {
#   provisioner "local-exec" {
#     command = "sqlcmd -S ${module.azure_sql.fully_qualified_domain_name} -d ${var.prefix} ---authentication-method ActiveDirectoryDefault -Q \"CREATE USER [${local.aks_uai_name}] FROM EXTERNAL PROVIDER WITH OBJECT_ID='${module.aks_usi.user_assinged_identity_principal_id}';ALTER ROLE db_datareader ADD MEMBER [${local.aks_uai_name}];\""
#   }
#   depends_on = [module.azure_sql]
# }

resource "null_resource" "run_sql_script" {
  provisioner "local-exec" {
    command = <<EOT
      sqlcmd --authentication-method=ActiveDirectoryAzCli \
             -S ${module.azure_sql.server_fqdn} \
             -d ${var.resource_name} \
             -Q "IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'${var.resource_name}') BEGIN CREATE USER [${var.resource_name}] FROM EXTERNAL PROVIDER WITH OBJECT_ID='${module.user_assigned_identity.principal_id}'; ALTER ROLE db_datareader ADD MEMBER [${var.resource_name}]; END"
    EOT
  }
  triggers = {
    always_run = "${timestamp()}"
  }
  depends_on = [module.azure_sql]
}
