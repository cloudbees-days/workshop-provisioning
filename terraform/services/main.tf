variable "domain" {
  type = string
}

terraform {
  backend "gcs" {
    bucket = "cbws1-cluster"
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


resource "helm_release" "nginx-ingress" {
  name       = "ingress-nginx"
  repository = "https://kubernetes-charts.storage.googleapis.com"
  chart      = "stable/nginx-ingress"
  namespace  = "ingress-nginx"
  version    = "1.4.0"

  values = [
    "${file("./../../helm/nginx.yml")}"
  ]
}

# resource "helm_release" "cert-manager" {
#   name       = "cert-manager"
#   repository = data.helm_repository.jetstack.metadata[0].name
#   chart      = "jetstack/cert-manager"
#   namespace  = "cert-manager"

#   values = [
#     "${file("./../../helm/cert-manager.yml")}"
#   ]
# }

resource "helm_release" "core" {
  name       = "core"
  repository = "https://charts.cloudbees.com/public/cloudbees"
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
    namespace = "cloudbees-core"
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
    namespace = "cloudbees-core"
  }

  data = {
    POSTGRES_USER     = random_string.db_username.result
    POSTGRES_PASSWORD = random_string.db_password.result
    POSTGRES_DB       = random_string.db_name.result
    POSTGRES_PORT     = 5432
    POSTGRES_SERVICE  = kubernetes_service.postgresdb.metadata[0].name
  }
}


resource "kubernetes_deployment" "postgresdb" {
  metadata {
    name = "postgresdb"
    namespace = "cloudbees-core"
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

  depends_on = [
    kubernetes_secret.postgresdb
  ]
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
    namespace = "cloudbees-core"
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
          image_pull_policy = "Always"
          env_from {
            secret_ref {
              name = "postgresdb"
            }
          }
        }
        init_container {
          name = "db-migration"
          image = "gcr.io/cb-days-workshop/microblog-backend"
          command = ["sh", "-c", "python manage.py migrate"]
          env_from {
            secret_ref {
              name = "postgresdb"
            }
          }
        }
      }
    }
  }
  depends_on = [
    kubernetes_secret.postgresdb
  ]
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
      "cert-manager.io/cluster-issuer": "letsencrypt-prod"
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
      host = "backend.${var.domain}"
    }

    tls {
      secret_name = "backend-tls"
      hosts = ["backend.${var.domain}"]
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


