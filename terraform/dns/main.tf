variable "project" {
  type = string
}

variable "domain" {
  type = string
}

variable "domain_zone" {
  type = string
}

variable "region" {
  type = string
}


terraform {
  backend "gcs" {
    bucket  = "cbws1-cluster"
    prefix  = "terraform/state/dns"
  }
}

provider "google" {
  project = var.project
  region  = var.region
}

provider "kubernetes" {
  config_path = "${path.module}/../kubeconfig"
}

data "kubernetes_service" "nginx-ingress-controller" {
  metadata {
    name      = "ingress-nginx-nginx-ingress-controller"
    namespace = "ingress-nginx"
  }
}

resource "google_dns_record_set" "core" {
  name = "*.${var.domain}."
  type = "A"
  ttl  = 30

  managed_zone = var.domain_zone

  rrdatas = [data.kubernetes_service.nginx-ingress-controller.load_balancer_ingress[0]["ip"]]
}
