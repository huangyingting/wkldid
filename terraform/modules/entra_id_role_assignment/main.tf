resource "azuread_directory_role" "privileged_role_administrator" {
  display_name = var.role_name
}

resource "azuread_directory_role_assignment" "role_assignment" {
  role_id             = azuread_directory_role.privileged_role_administrator.template_id
  principal_object_id = var.principal_id
}
