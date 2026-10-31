# Azure Database for PostgreSQL Flexible Server (Burstable B1ms by default).
# Public endpoint restricted to Azure services (0.0.0.0 rule); TLS is enforced.
# For production, use VNet integration (delegated_subnet_id) instead.
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "name" { type = string }
variable "database" { type = string }
variable "admin_user" { type = string }
variable "postgres_version" {
  type    = string
  default = "16"
}
variable "sku_name" {
  type    = string
  default = "B_Standard_B1ms"
}
variable "storage_mb" {
  type    = number
  default = 32768
}

resource "random_password" "db" {
  length  = 32
  special = false
}

# Not prevent_destroy: these stacks are meant to be torn down with `terraform destroy`.
# tflint-ignore: azurerm_resources_missing_prevent_destroy
resource "azurerm_postgresql_flexible_server" "this" {
  name                          = var.name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  version                       = var.postgres_version
  sku_name                      = var.sku_name
  storage_mb                    = var.storage_mb
  administrator_login           = var.admin_user
  administrator_password        = random_password.db.result
  backup_retention_days         = 7
  public_network_access_enabled = true
  lifecycle {
    ignore_changes = [zone]
  }
}

# tflint-ignore: azurerm_resources_missing_prevent_destroy
resource "azurerm_postgresql_flexible_server_database" "this" {
  name      = var.database
  server_id = azurerm_postgresql_flexible_server.this.id
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "azure" {
  name             = "allow-azure-services"
  server_id        = azurerm_postgresql_flexible_server.this.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

output "host" { value = azurerm_postgresql_flexible_server.this.fqdn }
output "database" { value = azurerm_postgresql_flexible_server_database.this.name }
output "user" { value = var.admin_user }
output "password" {
  value     = random_password.db.result
  sensitive = true
}
