# Memorystore for Redis (Basic tier) on the private network. Not used by the
# current apps; kept for apps that need a cache or queue.
variable "project_id" { type = string }
variable "region" { type = string }
variable "name" { type = string }
variable "network_id" { type = string }
variable "private_services_connection" { type = string }
variable "memory_size_gb" {
  type    = number
  default = 1
}

resource "google_project_service" "redis" {
  project            = var.project_id
  service            = "redis.googleapis.com"
  disable_on_destroy = false
}

resource "google_redis_instance" "this" {
  project                 = var.project_id
  name                    = var.name
  region                  = var.region
  tier                    = "BASIC"
  memory_size_gb          = var.memory_size_gb
  authorized_network      = var.network_id
  connect_mode            = "PRIVATE_SERVICE_ACCESS"
  auth_enabled            = true
  transit_encryption_mode = "SERVER_AUTHENTICATION"
  depends_on              = [google_project_service.redis, var.private_services_connection]
}

output "host" { value = google_redis_instance.this.host }
output "port" { value = google_redis_instance.this.port }
