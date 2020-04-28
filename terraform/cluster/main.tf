provider "google" {
  project = "ldonley"
  region  = "us-central1"
}

provider "google-beta" {
  project = "ldonley"
  region  = "us-central1"
}

resource "random_id" "username" {
  byte_length = 14
}

resource "random_id" "password" {
  byte_length = 16
}

resource "google_container_cluster" "primary" {
  provider                 = google-beta
  name                     = "logan-cluster"
  location                 = "us-central1-a"
  remove_default_node_pool = true
  initial_node_count       = 1

  workload_identity_config {
    identity_namespace = "ldonley.svc.id.goog"
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
  node_count = 1

  autoscaling {
    min_node_count = 1
    max_node_count = 10
  }

  node_config {
    preemptible  = false
    machine_type = "n2-standard-4"

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
