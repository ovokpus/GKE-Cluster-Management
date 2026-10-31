# One Cloud Run (v2) service. Optional direct VPC egress for private databases and
# env vars sourced from Secret Manager.
variable "project_id" { type = string }
variable "region" { type = string }
variable "name" { type = string }
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
  description = "ENV_NAME => Secret Manager secret id (latest version is used)."
  type        = map(string)
  default     = {}
}
variable "cpu" {
  type    = string
  default = "1"
}
variable "memory" {
  type    = string
  default = "512Mi"
}
variable "min_instances" {
  type    = number
  default = 0
}
variable "max_instances" {
  type    = number
  default = 2
}
variable "public" {
  description = "Allow unauthenticated invocations (allUsers run.invoker)."
  type        = bool
  default     = true
}
variable "vpc" {
  description = "Direct VPC egress: { network = id, subnet = id } or null."
  type        = object({ network = string, subnet = string })
  default     = null
}
variable "health_path" {
  type    = string
  default = "/"
}

resource "google_project_service" "run" {
  project            = var.project_id
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_service_account" "this" {
  project      = var.project_id
  account_id   = substr("run-${var.name}", 0, 30)
  display_name = "Cloud Run ${var.name}"
}

resource "google_secret_manager_secret_iam_member" "access" {
  for_each  = var.secret_env
  project   = var.project_id
  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.this.email}"
}

resource "google_cloud_run_v2_service" "this" {
  project             = var.project_id
  name                = var.name
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false
  template {
    service_account = google_service_account.this.email
    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }
    dynamic "vpc_access" {
      for_each = var.vpc == null ? [] : [var.vpc]
      content {
        egress = "PRIVATE_RANGES_ONLY"
        network_interfaces {
          network    = vpc_access.value.network
          subnetwork = vpc_access.value.subnet
        }
      }
    }
    containers {
      image = var.image
      ports {
        container_port = var.port
      }
      resources {
        limits = { cpu = var.cpu, memory = var.memory }
      }
      dynamic "env" {
        for_each = var.env
        content {
          name  = env.key
          value = env.value
        }
      }
      dynamic "env" {
        for_each = var.secret_env
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value
              version = "latest"
            }
          }
        }
      }
      startup_probe {
        http_get {
          path = var.health_path
        }
      }
    }
  }
  depends_on = [google_project_service.run, google_secret_manager_secret_iam_member.access]
}

resource "google_cloud_run_v2_service_iam_member" "public" {
  count    = var.public ? 1 : 0
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.this.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

output "url" { value = google_cloud_run_v2_service.this.uri }
output "service_account_email" { value = google_service_account.this.email }
