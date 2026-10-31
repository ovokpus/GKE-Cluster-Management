# Manually triggered Container Apps job (batch / seed).
# Start it with: az containerapp job start -n <name> -g <resource group>
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "name" { type = string }
variable "environment_id" { type = string }
variable "identity_id" { type = string }
variable "registry_server" { type = string }
variable "image" { type = string }
variable "command" {
  type    = list(string)
  default = []
}
variable "args" {
  type    = list(string)
  default = []
}
variable "env" {
  type    = map(string)
  default = {}
}
variable "secret_env" {
  type      = map(string)
  default   = {}
  sensitive = true
}
variable "cpu" {
  type    = number
  default = 1
}
variable "memory" {
  type    = string
  default = "2Gi"
}
variable "timeout_seconds" {
  type    = number
  default = 1800
}

locals {
  secret_names = { for k in nonsensitive(keys(var.secret_env)) : k => replace(lower(k), "_", "-") }
}

resource "azurerm_container_app_job" "this" {
  name                         = var.name
  resource_group_name          = var.resource_group_name
  location                     = var.location
  container_app_environment_id = var.environment_id
  replica_timeout_in_seconds   = var.timeout_seconds
  replica_retry_limit          = 1
  manual_trigger_config {
    parallelism              = 1
    replica_completion_count = 1
  }
  identity {
    type         = "UserAssigned"
    identity_ids = [var.identity_id]
  }
  registry {
    server   = var.registry_server
    identity = var.identity_id
  }
  dynamic "secret" {
    for_each = local.secret_names
    content {
      name  = secret.value
      value = var.secret_env[secret.key]
    }
  }
  template {
    container {
      name    = "job"
      image   = var.image
      cpu     = var.cpu
      memory  = var.memory
      command = length(var.command) > 0 ? var.command : null
      args    = length(var.args) > 0 ? var.args : null
      dynamic "env" {
        for_each = var.env
        content {
          name  = env.key
          value = env.value
        }
      }
      dynamic "env" {
        for_each = local.secret_names
        content {
          name        = env.key
          secret_name = env.value
        }
      }
    }
  }
}

output "name" { value = azurerm_container_app_job.this.name }
output "start_command" { value = "az containerapp job start -n ${azurerm_container_app_job.this.name} -g ${var.resource_group_name}" }
