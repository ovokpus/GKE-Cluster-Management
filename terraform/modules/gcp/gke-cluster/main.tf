# Regional GKE Standard cluster with a separately managed, autoscaling node pool.
# Folded in from ovokpus/GCP-Terraform-App-Deployment (google_container_cluster.primary,
# google_container_node_pool.primary_nodes), modernised: private nodes, workload
# identity, no default 0.0.0.0/0 control-plane access, shielded nodes.
variable "project_id" { type = string }
variable "region" { type = string }
variable "name" { type = string }
variable "network_id" { type = string }
variable "subnet_id" { type = string }
variable "machine_type" {
  type    = string
  default = "e2-standard-2"
}
variable "min_nodes" {
  type    = number
  default = 1
}
variable "max_nodes" {
  type    = number
  default = 3
}
variable "authorized_cidrs" {
  description = "CIDRs allowed to reach the control plane, e.g. your office IP."
  type        = list(string)
  default     = []
}

resource "google_project_service" "container" {
  project            = var.project_id
  service            = "container.googleapis.com"
  disable_on_destroy = false
}

resource "google_service_account" "nodes" {
  project    = var.project_id
  account_id = substr("gke-${var.name}-nodes", 0, 30)
}

resource "google_project_iam_member" "nodes" {
  for_each = toset(["roles/logging.logWriter", "roles/monitoring.metricWriter", "roles/artifactregistry.reader"])
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.nodes.email}"
}

resource "google_container_cluster" "this" {
  # No default node pool: newer GKE versions accept a cluster without initial nodes.
  project             = var.project_id
  name                = var.name
  location            = var.region
  network             = var.network_id
  subnetwork          = var.subnet_id
  deletion_protection = true
  networking_mode     = "VPC_NATIVE"
  ip_allocation_policy {}
  enable_intranode_visibility = true
  resource_labels             = { managed-by = "terraform" }
  network_policy {
    enabled  = true
    provider = "CALICO"
  }
  addons_config {
    network_policy_config {
      disabled = false
    }
  }
  release_channel {
    channel = "REGULAR"
  }
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }
  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.authorized_cidrs
      content {
        cidr_block = cidr_blocks.value
      }
    }
  }
  depends_on = [google_project_service.container]
}

resource "google_container_node_pool" "primary" {
  project  = var.project_id
  name     = "primary"
  location = var.region
  cluster  = google_container_cluster.this.name
  autoscaling {
    min_node_count = var.min_nodes
    max_node_count = var.max_nodes
  }
  management {
    auto_repair  = true
    auto_upgrade = true
  }
  node_config {
    machine_type    = var.machine_type
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}

output "name" { value = google_container_cluster.this.name }
output "endpoint" { value = google_container_cluster.this.endpoint }
output "get_credentials_command" { value = "gcloud container clusters get-credentials ${var.name} --region ${var.region} --project ${var.project_id}" }
