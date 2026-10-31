# Azure Container Registry (admin user off; pull with managed identity).
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "name" {
  description = "5-50 alphanumerics, globally unique."
  type        = string
}
variable "sku" {
  type    = string
  default = "Basic"
}

resource "azurerm_container_registry" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku
  admin_enabled       = false
}

output "id" { value = azurerm_container_registry.this.id }
output "login_server" { value = azurerm_container_registry.this.login_server }
