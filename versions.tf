terraform {
  required_providers {
    aviatrix = {
      source  = "aviatrixsystems/aviatrix"
      version = ">= 3.2.0"
    }
    # needed as the CoPilot is a VM to be spawned in Azure
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 1.0"
    }
    null = {
      source = "hashicorp/null"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.37.0"
    }
    google = {
      source = "hashicorp/google"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "> 5.47"
    }
  }
  required_version = ">= 1.0"
}
