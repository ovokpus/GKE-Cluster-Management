# Cloud SQL for PostgreSQL on a private IP. The password is generated and kept in
# Secret Manager; it is also in Terraform state, so protect the state bucket.
variable "project_id" { type = string }
variable "region" { type = string }
variable "name" { type = string }
variable "network_id" { type = string }
variable "private_services_connection" {
  description = "Output of the network module; makes sure peering exists first."
  type        = string
}
variable "database" { type = string }
variable "user" { type = string }
variable "database_version" {
  type    = string
  default = "POSTGRES_16"
}
variable "tier" {
  description = "Smallest shared-core tier by default. Change for real workloads."
  type        = string
  default     = "db-f1-micro"
}
variable "deletion_protection" {
  type    = bool
  default = true
}

resource "google_project_service" "apis" {
  for_each           = toset(["sqladmin.googleapis.com", "secretmanager.googleapis.com"])
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "random_password" "db" {
  length  = 32
  special = false
}

resource "google_sql_database_instance" "this" {
  project             = var.project_id
  name                = var.name
  region              = var.region
  database_version    = var.database_version
  deletion_protection = var.deletion_protection
  settings {
    tier                        = var.tier
    edition                     = "ENTERPRISE"
    deletion_protection_enabled = var.deletion_protection
    ip_configuration {
      ipv4_enabled    = false
      private_network = var.network_id
      ssl_mode        = "ENCRYPTED_ONLY"
    }
    backup_configuration {
      enabled = true
    }
    dynamic "database_flags" {
      for_each = { log_connections = "on", log_disconnections = "on", log_checkpoints = "on", log_lock_waits = "on" }
      content {
        name  = database_flags.key
        value = database_flags.value
      }
    }
  }
  depends_on = [google_project_service.apis, var.private_services_connection]
}

resource "google_sql_database" "this" {
  project  = var.project_id
  instance = google_sql_database_instance.this.name
  name     = var.database
}

resource "google_sql_user" "this" {
  project  = var.project_id
  instance = google_sql_database_instance.this.name
  name     = var.user
  password = random_password.db.result
}

resource "google_secret_manager_secret" "password" {
  project   = var.project_id
  secret_id = "${var.name}-db-password"
  replication {
    auto {}
  }
  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "password" {
  secret      = google_secret_manager_secret.password.id
  secret_data = random_password.db.result
}

output "private_ip" { value = google_sql_database_instance.this.private_ip_address }
output "database" { value = google_sql_database.this.name }
output "user" { value = google_sql_user.this.name }
output "password_secret_id" {
  description = "Secret Manager secret holding the password (use latest version)."
  value       = google_secret_manager_secret.password.secret_id
}
output "password" {
  value     = random_password.db.result
  sensitive = true
}
