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

resource "kubernetes_namespace" "flow" {
  metadata {
    name = "flow"

    labels = {
      app = "flow"
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
}

resource "helm_release" "flow" {
  name      = "flow"
  chart     = "cloudbees/cloudbees-flow"
  namespace = "flow"

  values = [
    "${file("./../../helm/flow.yml")}"
  ]
}

# resource "helm_release" "nexus" {
#   name      = "nexus"
#   chart     = "stable/sonatype-nexus"
#   namespace = "nexus"

#   values = [
#     "${file("./../../helm/nexus.yml")}"
#   ]
# }

data "kubernetes_service" "nginx-ingress-controller" {
  metadata {
    name      = "ingress-nginx-nginx-ingress-controller"
    namespace = "ingress-nginx"
  }
}


output "nginx-ingress-controller-ip" {
  value = "${data.kubernetes_service.nginx-ingress-controller.spec}"
}


