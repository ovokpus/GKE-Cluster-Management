# Container Apps environment + Log Analytics + a user-assigned identity that can
# pull from ACR. Pass identity_id / registry_server to container-app(-job).
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "name" { type = string }
variable "acr_id" { type = string }
variable "log_retention_days" {
  type    = number
  default = 30
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = "${var.name}-logs"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
}

resource "azurerm_container_app_environment" "this" {
  name                       = var.name
  resource_group_name        = var.resource_group_name
  location                   = var.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
}

resource "azurerm_user_assigned_identity" "pull" {
  name                = "${var.name}-acr-pull"
  resource_group_name = var.resource_group_name
  location            = var.location
}

resource "azurerm_role_assignment" "pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.pull.principal_id
}

output "id" { value = azurerm_container_app_environment.this.id }
output "identity_id" { value = azurerm_user_assigned_identity.pull.id }
output "default_domain" { value = azurerm_container_app_environment.this.default_domain }
