variable "domain" {
  type = string
}

terraform {
  backend "gcs" {
    bucket = "ld-cluster-state"
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

data "helm_repository" "stable" {
  name = "stable"
  url  = "https://kubernetes-charts.storage.googleapis.com"
}

data "helm_repository" "cloudbees" {
  name = "cloudbees"
  url  = "https://charts.cloudbees.com/public/cloudbees"
}

data "helm_repository" "jetstack" {
  name = "jetstack"
  url  = "https://charts.jetstack.io"
}

# resource "kubernetes_role" "cjoc-agents" {
#   metadata {
#     name      = "cjoc-agents"
#     namespace = "cloudbees-core"
#   }

#   rule {
#     api_groups = [""]
#     resources  = ["pods"]
#     verbs      = ["create", "delete", "get", "list", "patch", "update", "watch"]
#   }
#   rule {
#     api_groups = [""]
#     resources  = ["pods/exec"]
#     verbs      = ["create", "delete", "get", "list", "patch", "update", "watch"]
#   }
#   rule {
#     api_groups = [""]
#     resources  = ["deployments"]
#     verbs      = ["get", "list", "watch"]
#   }
#   rule {
#     api_groups = ["apps"]
#     resources  = ["deployments"]
#     verbs      = ["create", "delete", "get", "list", "patch", "update", "watch"]
#   }
#   rule {
#     api_groups = [""]
#     resources  = ["services"]
#     verbs      = ["create", "delete", "get", "list", "patch", "update", "watch"]
#   }
#   rule {
#     api_groups = [""]
#     resources  = ["secrets"]
#     verbs      = ["create", "delete", "get", "list", "patch", "update", "watch"]
#   }
#   rule {
#     api_groups = [""]
#     resources  = ["persistentvolumeclaims"]
#     verbs      = ["create", "delete", "get", "list", "patch", "update", "watch"]
#   }
#   rule {
#     api_groups = ["extensions"]
#     resources  = ["ingresses"]
#     verbs      = ["create", "delete", "get", "list", "patch", "update", "watch"]
#   }
# }

resource "helm_release" "nginx-ingress" {
  name       = "ingress-nginx"
  repository = data.helm_repository.stable.metadata[0].name
  chart      = "stable/nginx-ingress"
  namespace  = "ingress-nginx"
  version    = "1.4.0"

  values = [
    "${file("./../../helm/nginx.yml")}"
  ]
}

resource "helm_release" "cert-manager" {
  name       = "cert-manager"
  repository = data.helm_repository.jetstack.metadata[0].name
  chart      = "jetstack/cert-manager"
  namespace  = "cert-manager"

  values = [
    "${file("./../../helm/cert-manager.yml")}"
  ]
}

resource "helm_release" "core" {
  name       = "core"
  repository = data.helm_repository.cloudbees.metadata[0].name
  chart      = "cloudbees/cloudbees-core"
  namespace  = "cloudbees-core"

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

resource "kubernetes_persistent_volume_claim" "postgresdb" {
  metadata {
    name = "postgresdb"
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "5Gi"
      }
    }
  }
}

resource "kubernetes_secret" "postgresdb" {
  metadata {
    name = "postgresdb"
  }

  data = {
    POSTGRES_USER     = random_string.db_username.result
    POSTGRES_PASSWORD = random_string.db_password.result
    POSTGRES_DB       = random_string.db_name.result
  }
}


resource "kubernetes_deployment" "postgresdb" {
  metadata {
    name = "postgresdb"
    labels = {
      app = "postgresdb"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "postgresdb"
      }
    }

    template {
      metadata {
        labels = {
          app = "postgresdb"
        }
      }

      spec {
        container {
          image = "postgres:12.1-alpine"
          name  = "postgresdb"
          env_from {
            secret_ref {
              name = "postgresdb"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "postgresdb" {
  metadata {
    name      = "postgresdb"
    namespace = "cloudbees-core"
  }
  spec {
    selector = {
      app = "${kubernetes_deployment.postgresdb.metadata.0.labels.app}"
    }
    port {
      port        = 5432
      target_port = 5432
    }
    type = "ClusterIP"
  }
}


resource "kubernetes_deployment" "microblog-backend" {
  metadata {
    name = "microblog-backend"
    labels = {
      app = "microblog-backend"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "microblog-backend"
      }
    }

    template {
      metadata {
        labels = {
          app = "microblog-backend"
        }
      }

      spec {
        container {
          image = "gcr.io/cb-days-workshop/microblog-backend"
          name  = "microblog-backend"
        }
      }
    }
  }
}

resource "kubernetes_service" "microblog-backend" {
  metadata {
    name      = "microblog-backend"
    namespace = "cloudbees-core"
  }
  spec {
    selector = {
      app = "${kubernetes_deployment.microblog-backend.metadata.0.labels.app}"
    }
    port {
      port        = 80
      target_port = 8000
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_ingress" "microblog-backend" {
  metadata {
    name      = "microblog-backend"
    namespace = "cloudbees-core"
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
    }
  }

  spec {
    rule {
      http {
        path {
          backend {
            service_name = "microblog-backend"
            service_port = 80
          }

          path = "/"
        }
      }
    }

    tls {
      secret_name = "backend-tls"
    }
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


