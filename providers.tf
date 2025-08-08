provider "google" {
  project = "prjbetaaviatrixgcp"
  region  = "europe-west3"
}

provider "aws" {
  region     = "eu-central-1"
  access_key = var.aws_access
  secret_key = var.aws_secret
}

provider "azurerm" {
  features {}

  subscription_id = "7b15199c-09ec-4924-9493-d0452969667b"
  # client_id       = var.azure_appId
  # client_secret   = var.azure_password
  # tenant_id       = var.azure_tenant
  skip_provider_registration = true
}

#Aviatrix Provider
provider "aviatrix" {
  username                = "admin"
  password                = var.avx_controller_admin_password
  controller_ip           = var.controller_ip
  skip_version_validation = true
}

############################
# EKS: cluster data + token
############################

provider "kubernetes" {
  alias                  = "eks"
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  # Get token at runtime via AWS CLI (avoids data sources)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
  }
}


############################
# AKS: prefer user kube_config, fallback to admin
############################

# AKS provider: use admin kubeconfig straight from the resource

locals {
  aks_has_user_cfg  = length(azurerm_kubernetes_cluster.aks_cluster.kube_config) > 0
  aks_has_admin_cfg = length(azurerm_kubernetes_cluster.aks_cluster.kube_admin_config) > 0

  aks_host_b64 = (
    local.aks_has_user_cfg
    ? azurerm_kubernetes_cluster.aks_cluster.kube_config[0].host
    : azurerm_kubernetes_cluster.aks_cluster.kube_admin_config[0].host
  )

  aks_ca_b64 = (
    local.aks_has_user_cfg
    ? azurerm_kubernetes_cluster.aks_cluster.kube_config[0].cluster_ca_certificate
    : azurerm_kubernetes_cluster.aks_cluster.kube_admin_config[0].cluster_ca_certificate
  )

  aks_client_cert_b64 = (
    local.aks_has_user_cfg
    ? try(azurerm_kubernetes_cluster.aks_cluster.kube_config[0].client_certificate, null)
    : try(azurerm_kubernetes_cluster.aks_cluster.kube_admin_config[0].client_certificate, null)
  )

  aks_client_key_b64 = (
    local.aks_has_user_cfg
    ? try(azurerm_kubernetes_cluster.aks_cluster.kube_config[0].client_key, null)
    : try(azurerm_kubernetes_cluster.aks_cluster.kube_admin_config[0].client_key, null)
  )

  aks_username = (
    local.aks_has_user_cfg
    ? try(azurerm_kubernetes_cluster.aks_cluster.kube_config[0].username, null)
    : null
  )

  aks_password = (
    local.aks_has_user_cfg
    ? try(azurerm_kubernetes_cluster.aks_cluster.kube_config[0].password, null)
    : null
  )
}

provider "kubernetes" {
  alias                  = "aks"
  host                   = local.aks_host_b64
  cluster_ca_certificate = base64decode(local.aks_ca_b64)
  client_certificate     = try(base64decode(local.aks_client_cert_b64), null)
  client_key             = try(base64decode(local.aks_client_key_b64), null)
  username               = local.aks_username
  password               = local.aks_password
}

### DURING PLAN AND APPLY IT TRIES TO FIND THE FILES (which get generated only later) and errors out requiring
### APPLY 2 x TIMES

# # Kubernetes provider using EKS kubeconfig generated before
# provider "kubernetes" {
#   alias       = "eks"
#   config_path = "${path.module}/kubeconfig-eks.yaml"
# }

# provider "kubernetes" {
#   alias = "aks"
#   config_path = "${path.module}/kubeconfig-aks.yaml" # your existing path, e.g. "~/.kube/config"
# }


