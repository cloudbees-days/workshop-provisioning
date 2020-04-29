variable "domain" {
  type = string
}

terraform {
  backend "gcs" {
    bucket  = "ld-cluster-state"
    prefix  = "terraform/state/services"
  }
}

provider "kubernetes" {
  config_path = "${path.module}/../kubeconfig"
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


resource "kubernetes_namespace" "nexus" {
  metadata {
    name = "nexus"

    labels = {
      app = "nexus"
    }
  }
}

provider "helm" {
  kubernetes {
    config_path = "${path.module}/../kubeconfig"
  }
}

resource "helm_release" "nginx-ingress" {
  name      = "ingress-nginx"
  chart     = "stable/nginx-ingress"
  namespace = "ingress-nginx"
  version   = "1.4.0"

  values = [
    "${file("./../../helm/nginx.yml")}"
  ]
}

resource "helm_release" "cert-manager" {
  name      = "cert-manager"
  chart     = "jetstack/cert-manager"
  namespace = "cert-manager"

  values = [
    "${file("./../../helm/cert-manager.yml")}"
  ]
}

resource "helm_release" "core" {
  name      = "core"
  chart     = "cloudbees/cloudbees-core"
  namespace = "cloudbees-core"

  values = [
    "${file("./../../helm/core.yml")}"
  ]

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
}

# resource "helm_release" "nexus" {
#   name      = "nexus"
#   chart     = "stable/sonatype-nexus"
#   namespace = "nexus"

#   values = [
#     "${file("./../../helm/nexus.yml")}"
#   ]
# }


