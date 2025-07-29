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

# Kubernetes provider using EKS kubeconfig generated before
provider "kubernetes" {
  alias       = "eks"
  config_path = "${path.module}/kubeconfig-eks.yaml"
}

provider "kubernetes" {
  alias = "aks"
  #config_path = "${path.module}/kubeconfig-aks.yaml" # your existing path, e.g. "~/.kube/config"
  config_path = local_file.aks_kubeconfig.filename
}

# using Helm for Metrics installation for EKS to be able to do kubectl top pods / nodes

