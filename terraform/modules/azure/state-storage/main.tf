# Storage account + private container for the azurerm Terraform backend.
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "account_name" {
  description = "3-24 lowercase letters/digits, globally unique."
  type        = string
}
variable "container_name" {
  type    = string
  default = "tfstate"
}

resource "azurerm_storage_account" "this" {
  name                            = var.account_name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "GRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  lifecycle {
    prevent_destroy = true
  }
  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 14
    }
  }
}

resource "azurerm_storage_container" "this" {
  name                  = var.container_name
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
  lifecycle {
    prevent_destroy = true
  }
}

output "storage_account_name" { value = azurerm_storage_account.this.name }
output "container_name" { value = azurerm_storage_container.this.name }
