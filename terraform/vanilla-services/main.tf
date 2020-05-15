variable "domain" {
  type = string
}

variable "oc_memory" {
  type    = string
  default = "8G"
}

variable "oc_cpu" {
  type    = string
  default = "2"
}

terraform {
  backend "gcs" {
    bucket = "my_bucket"
    prefix = "terraform/state/services"
  }
}

provider "kubernetes" {
  config_path = "${path.module}/../kubeconfig"
}

resource "random_string" "db_username" {
  length  = 16
  special = false
}

resource "random_string" "db_password" {
  length  = 30
  special = false
}

resource "random_string" "db_name" {
  length  = 16
  special = false
}

resource "kubernetes_namespace" "ingress-nginx" {
  metadata {
    name = "ingress-nginx"

    labels = {
      app = "nginx-ingress"
    }
  }
}

resource "kubernetes_namespace" "cert-manager" {
  metadata {
    name = "cert-manager"

    labels = {
      app = "cert-manager"
    }
  }
}

resource "kubernetes_namespace" "cloudbees-core" {
  metadata {
    name = "cloudbees-core"

    labels = {
      app = "cloudbees-core"
    }
  }
}

provider "helm" {
  kubernetes {
    config_path = "${path.module}/../kubeconfig"
  }
}


resource "helm_release" "nginx-ingress" {
  name       = "ingress-nginx"
  repository = "https://kubernetes-charts.storage.googleapis.com"
  chart      = "nginx-ingress"
  namespace  = "ingress-nginx"

  values = [
    "${file("./../../helm/nginx.yml")}"
  ]
}

resource "helm_release" "core" {
  name       = "core"
  repository = "https://charts.cloudbees.com/public/cloudbees"
  chart      = "cloudbees-core"
  namespace  = "cloudbees-core"


  set {
    name  = "OperationsCenter.HostName"
    value = "core.${var.domain}"
  }

  set {
    name  = "nginx-ingress.Enabled"
    value = "false"
  }

  set {
    name  = "OperationsCenter.Ingress.tls.Host"
    value = "core.${var.domain}"
  }
  
  set {
    name  = "OperationsCenter.Ingress.tls.Enable"
    value = "true"
  }

  set {
    name = "OperationsCenter.Ingress.Annotations.cert-manager.io/cluster-issuer"
    value = "letsencrypt-prod"
  }

  set {
    name  = "OperationsCenter.Cpu"
    value = var.oc_cpu
  }

  set {
    name  = "OperationsCenter.Memory"
    value = var.oc_memory
  }
}