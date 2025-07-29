## EKS PART

# App is Web Server from container I published on Docker Hub
# write votes in Postgres DB
# read votes from Redis 

## EKS PART

## FLOW IS
## PC CLIENT --> EKS LB --> WEB APP on 2 pods --> connects to PostGres/Redis over VIP exposed by Spoke in Azure --> ends up in overlapping
## internal LB IP in AKS --> goes to Postgres/Redis PODs

resource "kubernetes_namespace" "vote_ns" {
  provider = kubernetes.eks
  metadata {
    name = "aviatrix-vote"
  }
  depends_on = [null_resource.generate_kubeconfig]
}

resource "kubernetes_deployment" "vote_app" {
  provider   = kubernetes.eks
  depends_on = [kubernetes_namespace.vote_ns, null_resource.generate_kubeconfig]
  metadata {
    name      = "aviatrix-vote"
    namespace = kubernetes_namespace.vote_ns.metadata[0].name
    labels    = { app = "aviatrix-vote" }
  }

  spec {
    replicas = 1
    selector {
      match_labels = { app = "aviatrix-vote" }
    }

    template {
      metadata {
        labels = { app = "aviatrix-vote" }
      }
      spec {
        container {
          name  = "vote"
          image = "docker.io/mtanasescu/demo-vote:latest"
          port {
            container_port = 80
          }

          env {
            name  = "REDIS_HOST"
            value = var.azure_redis_avx_vip
          }
          env {
            name  = "POSTGRES_HOST"
            value = var.azure_postgres_avx_vip
          }
          env {
            name  = "POSTGRES_DB"
            value = var.postgres_db
          }
          env {
            name  = "POSTGRES_USER"
            value = "postgres"
          }
          env {
            name  = "POSTGRES_PASSWORD"
            value = var.postgres_password
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 10
            period_seconds        = 15 # Less frequent checking
            timeout_seconds       = 5  # Give more time to respond
            failure_threshold     = 3
            success_threshold     = 1
          }

          liveness_probe {
            http_get {
              path = "/" # Consider a dedicated /health endpoint
              port = 80
            }
            initial_delay_seconds = 30 # Give more time on startup
            period_seconds        = 10 # Much less frequent checks
            timeout_seconds       = 5  # More time to respond
            failure_threshold     = 5  # Be more forgiving
          }
        }
      }
    }

    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_surge       = "25%"
        max_unavailable = "25%"
      }
    }
  }
}

resource "kubernetes_service" "vote_svc" {
  provider   = kubernetes.eks
  depends_on = [kubernetes_deployment.vote_app, null_resource.generate_kubeconfig]
  metadata {
    name      = "aviatrix-vote"
    namespace = kubernetes_namespace.vote_ns.metadata[0].name
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "instance"
      "service.beta.kubernetes.io/aws-load-balancer-type"            = "nlb"
      "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internet-facing"
    }
  }
  spec {
    selector = {
      app = kubernetes_deployment.vote_app.metadata[0].labels.app
    }
    port {
      port        = 80
      target_port = 80
    }
    external_traffic_policy = "Local"
    type                    = "LoadBalancer"
  }
}

output "vote_service_lb_hostname" {
  value = kubernetes_service.vote_svc.status[0].load_balancer[0].ingress[0].hostname
}
