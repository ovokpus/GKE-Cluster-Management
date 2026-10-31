# One Cloud Run job (batch/seed). Run it with: gcloud run jobs execute <name> --region <region>
variable "project_id" { type = string }
variable "region" { type = string }
variable "name" { type = string }
variable "image" { type = string }
variable "args" {
  type    = list(string)
  default = []
}
variable "command" {
  type    = list(string)
  default = []
}
variable "env" {
  type    = map(string)
  default = {}
}
variable "secret_env" {
  type    = map(string)
  default = {}
}
variable "cpu" {
  type    = string
  default = "1"
}
variable "memory" {
  type    = string
  default = "1Gi"
}
variable "timeout" {
  type    = string
  default = "1800s"
}
variable "vpc" {
  type    = object({ network = string, subnet = string })
  default = null
}

resource "google_project_service" "run" {
  project            = var.project_id
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_service_account" "this" {
  project      = var.project_id
  account_id   = substr("job-${var.name}", 0, 30)
  display_name = "Cloud Run job ${var.name}"
}

resource "google_secret_manager_secret_iam_member" "access" {
  for_each  = var.secret_env
  project   = var.project_id
  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.this.email}"
}

resource "google_cloud_run_v2_job" "this" {
  project             = var.project_id
  name                = var.name
  location            = var.region
  deletion_protection = false
  template {
    template {
      service_account = google_service_account.this.email
      timeout         = var.timeout
      max_retries     = 1
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
        image   = var.image
        command = length(var.command) > 0 ? var.command : null
        args    = length(var.args) > 0 ? var.args : null
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
      }
    }
  }
  depends_on = [google_project_service.run, google_secret_manager_secret_iam_member.access]
}

output "name" { value = google_cloud_run_v2_job.this.name }
output "execute_command" { value = "gcloud run jobs execute ${google_cloud_run_v2_job.this.name} --region ${var.region} --project ${var.project_id} --wait" }
