output "project_id" {
  value = var.project_id
}

output "state_bucket" {
  value = var.state_bucket
}

output "cluster_name" {
  value = var.cluster_name
}

output "k8s_version" {
  value = var.k8s_version
}

output "region" {
  value = var.region
}

output "url" {
  value = "${google_cloud_run_service.default.status[0].url}"
}