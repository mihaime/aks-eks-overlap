

#----------------- AVIATRIX GENERIC -----------------
variable "avx_controller_admin_password" {
  type        = string
  description = "[sensitive.auto.tfvars] - aviatrix controller admin password"
}
variable "controller_ip" {
  type        = string
  description = "[terraform.auto.tfvars] - aviatrix controller "
}

#----------------- SSH KEY -----------------


variable "ssh_key" { default = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC9lhwk6x8eC+XDT8c0NQr4mxGfCKqCdfWqGkIzaC952Vg/6TKe/YpuiWibMVMUoRg8jm3jFXExzNZoKA86yEDEo4n9u5FVQA7UiFEEMd7fjjwFOQI60K7hgJjEUY/puqVobRnNAXUSk7bfqYAYOw6QK+DLu3z7jK1Mjcb7LJVQPWWZLq1jVSosF5drPbbEo++m2UstA8ZZHewGYdecs6SieeZjcovOrlQv9NONHjiszbN69zyuTcFJheT+U7opadz3WyI8A9zW//bp238+F5pPK+5dBY0+DQHEzGx1XCZzZJ+8mKULbJAb2q3oZG7S+AJ8jABKjCHNHxdZIVf/tHpD3WgqpRDRj6XEQFyXksTNKl+LC/gZmxxddlDMkNab4ZJqUesz0JBlgfV4z9w4Y3EagA1uQmcM8okQZjSq3akfEbhiApN1yiPFAlxTMVgVyqdlNe/kWUoVVbohOFKPVjU/tDaMSQj6iuSVzFONwckFczzTefEhIJdmyP5YxFQWSqeuIXmlpJOswVjnnqgiOijiavZ1dgo1kGhXI9GmZX6ZgvrEcPcNpp20Jrtey2QHssAOxjf1ndq8vydf64kE68rLQLL0sMulcbbW2DmkSTkMOAM5NM9ZBlCRh7ovW88zRsI+EENrINorpBN6Fvlllydppgrabv1WW+4cTFOZVmdYtw== mihaitanasescu@Mihais-MacBook-Pro.local" }

#----------------- AWS/AZURE PROVIDER GENERIC -----------------


# these will come automatically from AZ CLI when using it locally on my Mac

variable "azure_subscription_id" { type = string }
variable "azure_appId" { type = string }
variable "azure_password" { type = string }
variable "azure_tenant" { type = string }

variable "aws_access" { type = string }
variable "aws_secret" { type = string }

## 

variable "aws_region" {
  description = "AWS region for the transit gateway"
  type        = string
  default     = "eu-central-1"
}

variable "azure_region" {
  description = "Azure region for the transit gateway"
  type        = string
  default     = "West Europe"
}

#----------------- DEPLOYMENT SPECIFIC KEY -----------------


variable "avx_ctrl_account_aws" {
  description = "Name of the AWS cloud account onboarded in the Aviatrix controller"
  type        = string
}

variable "avx_ctrl_account_azure" {
  description = "Name of the Azure cloud account onboarded in the Aviatrix controller"
  type        = string
}



variable "aws_transit_vpc_id" {
  description = "VPC ID for AWS transit gateway"
  type        = string
  default     = ""
}

variable "azure_transit_vnet_name" {
  description = "VNet name for Azure transit gateway"
  type        = string
  default     = ""

}

variable "aws_transit_subnet" {
  description = "Subnet CIDR block for AWS transit gateway"
  type        = string
  default     = "192.168.10.0/28"
}

variable "azure_resource_group" {
  description = "Azure resource group for the transit VNet"
  type        = string
  default     = ""

}


variable "azure_transit_subnet" {
  description = "Subnet CIDR block for Azure transit gateway"
  type        = string
  default     = "192.168.20.0/28"
}

# AWS side represented to Azure 
variable "aws_snat_vip" {
  type    = string
  default = "172.16.10.100"
}

# AWS cidrs

variable "aws_spoke_vpc_cidr" {
  default = "10.100.0.0/16"
}

variable "aws_spoke_gw_subnet_cidr" {
  default = "10.100.0.0/28"
}

variable "aws_eks_node_subnet_cidr" {
  default = "10.100.1.0/24"
}

variable "aws_internal_lb_subnet_cidr" {
  default = "10.100.2.0/24"
}

variable "aws_pod_subnet_cidr" {
  default = "10.100.4.0/22"
}

# not needed - default range in AWS EKS
# variable "aws_service_subnet_cidr" {
#   default = "172.20.0.0/16"
# }

# Azure CIDRs

variable "azure_spoke_vnet_cidr" {
  default = "10.100.0.0/16"
}

variable "azure_spoke_gw_subnet_cidr" {
  default = "10.100.0.0/28"
}

variable "azure_aks_node_subnet_cidr" {
  default = "10.100.1.0/24"
}

variable "azure_internal_lb_subnet_cidr" {
  default = "10.100.2.0/24"
}

# not needed, taken from Node Subnet 
# variable "azure_pod_subnet_cidr" {
#   default = "10.100.4.0/22"
# }

variable "azure_secondary_vnet_cidr" {
  default = "172.20.0.0/16"
}

variable "azure_service_subnet_cidr" {
  default = "172.20.0.0/16"
}


# EKS AWS CLI Profile for used when generating kubeconfig
variable "aws_profile" { default = "default" }

# VOTING APP SPECIFIC 

## REDIS and POSTGRES VIPs exposed from Azure via VIP on Avx GW

variable "azure_postgres_avx_vip" {
  type    = string
  default = "172.20.20.101"
}
variable "azure_redis_avx_vip" {
  type    = string
  default = "172.20.20.100"
}

variable "azure_redis_lbip" {
  default = "10.100.2.50"
}

variable "azure_postgres_lbip" {
  default = "10.100.2.51"
}

## credentials

variable "postgres_password" {
  type        = string
  description = "[sensitive.auto.tfvars] - password for Postgres DB"
  default     = "demo_passwd"
}

variable "postgres_db" {
  type    = string
  default = "vote"
}
