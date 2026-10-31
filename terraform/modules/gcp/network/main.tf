# VPC + subnet + private services access, so Cloud Run (direct VPC egress) can reach
# Cloud SQL / Memorystore on private IPs. No public database endpoints.
variable "project_id" { type = string }
variable "region" { type = string }
variable "name" { type = string }
variable "cidr" {
  type    = string
  default = "10.10.0.0/24"
}

resource "google_project_service" "apis" {
  for_each           = toset(["compute.googleapis.com", "servicenetworking.googleapis.com"])
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_compute_network" "this" {
  project                 = var.project_id
  name                    = var.name
  auto_create_subnetworks = false
  depends_on              = [google_project_service.apis]
}

resource "google_compute_subnetwork" "this" {
  project                  = var.project_id
  name                     = "${var.name}-${var.region}"
  region                   = var.region
  network                  = google_compute_network.this.id
  ip_cidr_range            = var.cidr
  private_ip_google_access = true
  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
  }
}

resource "google_compute_global_address" "psa" {
  project       = var.project_id
  name          = "${var.name}-psa"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 20
  network       = google_compute_network.this.id
}

resource "google_service_networking_connection" "psa" {
  network                 = google_compute_network.this.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.psa.name]
}

output "network_id" { value = google_compute_network.this.id }
output "subnet_id" { value = google_compute_subnetwork.this.id }
output "private_services_connection" {
  description = "Depend on this before creating private-IP databases."
  value       = google_service_networking_connection.psa.id
}
