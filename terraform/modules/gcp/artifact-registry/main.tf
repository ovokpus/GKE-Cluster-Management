# Docker repository in Artifact Registry. Adapted from ovokpus/GCP-Terraform-App-Deployment.
variable "project_id" { type = string }
variable "region" { type = string }
variable "repository_id" { type = string }
variable "keep_recent" {
  description = "Cleanup policy: keep this many most recent versions per image."
  type        = number
  default     = 10
}

resource "google_project_service" "artifactregistry" {
  project            = var.project_id
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "this" {
  project       = var.project_id
  location      = var.region
  repository_id = var.repository_id
  format        = "DOCKER"
  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"
    most_recent_versions {
      keep_count = var.keep_recent
    }
  }
  depends_on = [google_project_service.artifactregistry]
}

output "repository_url" {
  description = "Push images to <repository_url>/<image>:<tag>."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.this.repository_id}"
}
