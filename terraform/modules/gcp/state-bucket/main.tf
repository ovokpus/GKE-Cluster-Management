# GCS bucket for Terraform remote state (versioned, uniform access, no public access).
# Adapted from ovokpus/GCP-Terraform-App-Deployment (main.tf, google_storage_bucket.state).
variable "project_id" { type = string }
variable "name" { type = string }
variable "location" {
  type    = string
  default = "US"
}
variable "force_destroy" {
  type    = bool
  default = false
}

resource "google_storage_bucket" "state" {
  project                     = var.project_id
  name                        = var.name
  location                    = var.location
  force_destroy               = var.force_destroy
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  versioning {
    enabled = true
  }
}

output "bucket" { value = google_storage_bucket.state.name }
