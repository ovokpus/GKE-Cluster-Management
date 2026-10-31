provider "google" {
  credentials = "Application/account.json"
  project     = var.project_id
  region      = var.region
}

resource "google_storage_bucket" "state" {
  name          = var.state_bucket
  location      = var.region
  project       = var.project_id
  storage_class = "STANDARD"
  force_destroy = true
  versioning {
    enabled = true
  }
  uniform_bucket_level_access = true
}

terraform {
  backend "gcs" {
    bucket      = "tfproj-bucket-tfstate"
    prefix      = "terraform/state"
    credentials = "/usercode/account.json"
  }
}

resource "google_container_cluster" "primary" {
  name                     = var.cluster_name
  location                 = var.region
  remove_default_node_pool = true
  initial_node_count       = var.min_node_count
  deletion_protection      = false


  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "default"
    }
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

}

resource "google_container_node_pool" "primary_nodes" {
  name       = "primary-nodes"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = 1
  project    = var.project_id

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    preemptible  = var.preemptible
    machine_type = var.machine_type
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }
}

resource "google_artifact_registry_repository" "default" {
  project       = var.project_id
  location      = var.region
  repository_id = "cloud-run-artifact-regsitry"
  format        = "DOCKER"
  description   = "cloud-run repository"
}

resource "google_artifact_registry_repository_iam_binding" "default" {
  repository = google_artifact_registry_repository.default.name
  location   = var.region
  role       = "roles/artifactregistry.writer"
  project    = var.project_id

  members = [
    "serviceAccount:tf-proj@very-responsible-steven.iam.gserviceaccount.com"
  ]
}

resource "google_project_service" "run_api" {
  service = "run.googleapis.com"
  disable_on_destroy = true
}

resource "google_cloud_run_service" "default" {
name     = var.service_name
location = var.region
template {
    spec {
    containers {
        image = "us-central1-docker.pkg.dev/very-responsible-steven/cloud-run-artifact-regsitry/terraform-gcp:0.0.1"
    }
    }
}
traffic {
    percent         = 100
    latest_revision = true
}
}

data "google_iam_policy" "noauth" {
binding {
    role = "roles/run.invoker"
    members = [
    "serviceAccount:tf-proj@very-responsible-steven.iam.gserviceaccount.com",
    "user:ovo.okpubuluku@badal.io"
    ]
}
}

resource "google_cloud_run_service_iam_policy" "noauth" {
location    = google_cloud_run_service.default.location
project     = google_cloud_run_service.default.project
service     = google_cloud_run_service.default.name
policy_data = data.google_iam_policy.noauth.policy_data
}

