## AKS PART

# App is Web Server from container I published on Docker Hub
# write votes in Postgres DB
# read votes from Redis 

## AKS PART

## FLOW IS
## PC CLIENT --> EKS LB --> WEB APP on 2 pods --> connects to PostGres/Redis over VIP exposed by Spoke in Azure --> ends up in overlapping
## internal LB IP in AKS --> goes to Postgres/Redis PODs

resource "kubernetes_namespace" "vote_ns_backend" {
  provider = kubernetes.aks
  metadata {
    name = "aviatrix-vote"
  }
  depends_on = [azurerm_kubernetes_cluster.aks_cluster]
}

resource "time_sleep" "pause_before_redis" {
  create_duration = "5s"
}

resource "time_sleep" "pause_before_postgres" {
  create_duration = "5s"
}

# Redis Deployment
resource "kubernetes_deployment" "redis" {
  provider   = kubernetes.aks
  depends_on = [azurerm_kubernetes_cluster.aks_cluster, time_sleep.pause_before_redis, azurerm_role_assignment.aks_node_subnet_contributor, azurerm_role_assignment.aks_internal_lb_subnet_contributor]
  metadata {
    name      = "redis"
    namespace = kubernetes_namespace.vote_ns.metadata[0].name
    labels    = { app = "redis" }
  }
  spec {
    replicas = 1
    selector { match_labels = { app = "redis" } }
    template {
      metadata { labels = { app = "redis" } }
      spec {
        container {
          name  = "redis"
          image = "redis:7-alpine"
          port { container_port = 6379 }
        }
      }
    }
  }
}

# Redis Internal LB
resource "kubernetes_service" "redis" {
  depends_on = [time_sleep.pause_before_redis, azurerm_kubernetes_cluster.aks_cluster]
  provider   = kubernetes.aks
  metadata {
    name      = "redis"
    namespace = kubernetes_namespace.vote_ns.metadata[0].name
    annotations = {
      "service.beta.kubernetes.io/azure-load-balancer-internal"        = "true"
      "service.beta.kubernetes.io/azure-load-balancer-internal-subnet" = azurerm_subnet.azure_internal_lb_subnet.name
      "service.beta.kubernetes.io/azure-load-balancer-ipv4"            = var.azure_redis_lbip
    }
  }
  spec {
    selector = { app = kubernetes_deployment.redis.metadata[0].labels.app }
    port {
      protocol    = "TCP"
      port        = 6379
      target_port = 6379
    }
    type = "LoadBalancer"
  }
}

# Postgres Deployment
resource "kubernetes_deployment" "postgres" {
  depends_on = [azurerm_kubernetes_cluster.aks_cluster, time_sleep.pause_before_postgres, azurerm_role_assignment.aks_node_subnet_contributor, azurerm_role_assignment.aks_internal_lb_subnet_contributor]
  provider   = kubernetes.aks
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace.vote_ns.metadata[0].name
    labels    = { app = "postgres" }
  }
  spec {
    replicas = 1
    selector { match_labels = { app = "postgres" } }
    template {
      metadata { labels = { app = "postgres" } }
      spec {
        container {
          name  = "postgres"
          image = "postgres:15-alpine"
          env {
            name  = "POSTGRES_PASSWORD"
            value = "demo_passwd"
          }
          env {
            name  = "POSTGRES_DB"
            value = "vote"
          }
          port { container_port = 5432 }
        }
      }
    }
  }
}

# Postgres Internal LB
resource "kubernetes_service" "postgres" {
  depends_on = [time_sleep.pause_before_postgres, azurerm_role_assignment.aks_node_subnet_contributor, azurerm_role_assignment.aks_internal_lb_subnet_contributor]
  provider   = kubernetes.aks
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace.vote_ns.metadata[0].name
    annotations = {
      "service.beta.kubernetes.io/azure-load-balancer-internal"        = "true"
      "service.beta.kubernetes.io/azure-load-balancer-internal-subnet" = azurerm_subnet.azure_internal_lb_subnet.name
      "service.beta.kubernetes.io/azure-load-balancer-ipv4"            = var.azure_postgres_lbip
    }
  }
  spec {
    selector = { app = kubernetes_deployment.postgres.metadata[0].labels.app }
    port {
      protocol    = "TCP"
      port        = 5432
      target_port = 5432
    }
    type = "LoadBalancer"
  }
}

# Worker to sync Redis→Postgres
## REPLACED THE INTERNAL LB IPs with SVC DNS NAMES as the worker deployment was Crashlooping not reaching ILB and coming back
## into the cluster

resource "kubernetes_deployment" "worker" {
  depends_on = [azurerm_kubernetes_cluster.aks_cluster, azurerm_role_assignment.aks_node_subnet_contributor, azurerm_role_assignment.aks_internal_lb_subnet_contributor, kubernetes_service.redis, kubernetes_service.postgres]
  provider   = kubernetes.aks
  metadata {
    name      = "worker"
    namespace = kubernetes_namespace.vote_ns.metadata[0].name
    labels    = { app = "worker" }
  }
  spec {
    replicas = 1
    selector { match_labels = { app = "worker" } }
    template {
      metadata { labels = { app = "worker" } }
      spec {
        container {
          name  = "worker"
          image = "docker.io/mtanasescu/worker:latest"
          env {
            name  = "REDIS_HOST"
            value = kubernetes_service.redis.metadata[0].name
          }
          env {
            name  = "POSTGRES_HOST"
            value = kubernetes_service.postgres.metadata[0].name
          }
          env {
            name  = "POSTGRES_DB"
            value = var.postgres_db
          }
          env {
            name  = "POSTGRES_PASSWORD"
            value = var.postgres_password
          }
        }
      }
    }
  }
}

output "azure_redis_lbip" { value = var.azure_redis_lbip }
output "azure_postgres_lbip" { value = var.azure_postgres_lbip }
