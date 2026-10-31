variable "project_id" {
  type    = string
  default = "very-responsible-steven"
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "state_bucket" {
  type    = string
  default = "tfproj-bucket-tfstate"
}

variable "cluster_name" {
  type    = string
  default = "tf-gcp-cluster"
}

variable "service_name" {
  type    = string
  default = "tf-gcp-run"
}

variable "k8s_version" {
  type    = string
  default = 1.24
}

variable "min_node_count" {
  type    = number
  default = 1
}

variable "max_node_count" {
  type    = number
  default = 3
}

variable "machine_type" {
  type    = string
  default = "e2-standard-2"
}

variable "preemptible" {
  type    = bool
  default = true
}
