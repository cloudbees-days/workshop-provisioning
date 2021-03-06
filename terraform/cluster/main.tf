variable "project" {
  type = string
}

variable "region" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "machine_type" {
  type = string
  default = "n1-standard-8"
}

variable "node_count" {
  type    = number
  default = 1
}

variable "min_node_count" {
  type    = number
  default = 1
}

variable "max_node_count" {
  type    = number
  default = 10
}

variable "secondary_machine_type" {
  type = string
  default = "n1-standard-8"
}

variable "secondary_node_count" {
  type    = number
  default = 1
}

variable "secondary_min_node_count" {
  type    = number
  default = 1
}

variable "secondary_max_node_count" {
  type    = number
  default = 10
}

terraform {
  backend "gcs" {
    bucket = "my_bucket"
    prefix = "terraform/state/cluster"
  }
}

provider "google" {
  project = var.project
  region  = var.region
}

provider "google-beta" {
  project = var.project
  region  = var.region
}

resource "random_id" "username" {
  byte_length = 14
}

resource "random_id" "password" {
  byte_length = 16
}

resource "google_container_cluster" "primary" {
  provider                 = google-beta
  name                     = var.cluster_name
  location                 = "us-central1-a"
  remove_default_node_pool = true
  initial_node_count       = 1

  workload_identity_config {
    identity_namespace = "${var.project}.svc.id.goog"
  }

  maintenance_policy {
  recurring_window {
    start_time = "2020-05-15T04:00:00Z"
    end_time   = "2020-05-16T04:00:00Z"
    recurrence = "FREQ=WEEKLY;BYDAY=SA,SU"
  }
}

  master_auth {
    username = random_id.username.hex
    password = random_id.password.hex
  }
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "main-node-pool"
  location   = "us-central1-a"
  cluster    = google_container_cluster.primary.name
  node_count = var.node_count

  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  node_config {
    preemptible  = false
    machine_type = var.machine_type

    metadata = {
      disable-legacy-endpoints = "true"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

resource "google_container_node_pool" "secondary_nodes" {
  name       = "secondary-node-pool"
  location   = "us-central1-a"
  cluster    = google_container_cluster.primary.name
  node_count = var.secondary_node_count

  autoscaling {
    min_node_count = var.secondary_min_node_count
    max_node_count = var.secondary_max_node_count
  }

  node_config {
    preemptible  = false
    machine_type = var.secondary_machine_type

    metadata = {
      disable-legacy-endpoints = "true"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

data "template_file" "kubeconfig" {
  template = file("${path.module}/kubeconfig-template.yaml")

  vars = {
    cluster_name    = google_container_cluster.primary.name
    user_name       = google_container_cluster.primary.master_auth[0].username
    user_password   = google_container_cluster.primary.master_auth[0].password
    endpoint        = google_container_cluster.primary.endpoint
    cluster_ca      = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
    client_cert     = google_container_cluster.primary.master_auth[0].client_certificate
    client_cert_key = google_container_cluster.primary.master_auth[0].client_key
  }
}

resource "local_file" "kubeconfig" {
  content  = data.template_file.kubeconfig.rendered
  filename = "${path.module}/../kubeconfig"
}



output "kubeconfig_path" {
  value = local_file.kubeconfig.filename
}

