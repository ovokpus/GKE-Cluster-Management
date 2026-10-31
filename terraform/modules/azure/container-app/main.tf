# One Container App with HTTPS ingress.
variable "resource_group_name" { type = string }
variable "name" { type = string }
variable "environment_id" { type = string }
variable "identity_id" { type = string }
variable "registry_server" { type = string }
variable "image" { type = string }
variable "port" {
  type    = number
  default = 8080
}
variable "env" {
  type    = map(string)
  default = {}
}
variable "secret_env" {
  description = "ENV_NAME => secret value. Stored as a Container Apps secret (and in state)."
  type        = map(string)
  default     = {}
  sensitive   = true
}
variable "cpu" {
  type    = number
  default = 0.5
}
variable "memory" {
  type    = string
  default = "1Gi"
}
variable "min_replicas" {
  type    = number
  default = 0
}
variable "max_replicas" {
  type    = number
  default = 2
}
variable "external" {
  type    = bool
  default = true
}

locals {
  secret_names = { for k in nonsensitive(keys(var.secret_env)) : k => replace(lower(k), "_", "-") }
}

resource "azurerm_container_app" "this" {
  name                         = var.name
  resource_group_name          = var.resource_group_name
  container_app_environment_id = var.environment_id
  revision_mode                = "Single"
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
  ingress {
    external_enabled = var.external
    target_port      = var.port
    transport        = "auto"
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas
    container {
      name   = "app"
      image  = var.image
      cpu    = var.cpu
      memory = var.memory
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

output "url" { value = "https://${azurerm_container_app.this.ingress[0].fqdn}" }
output "fqdn" { value = azurerm_container_app.this.ingress[0].fqdn }
