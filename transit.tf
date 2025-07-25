# SPOKE-AWS with EKS behind 10/8
# SPOKE-AZURE with AKS behind 10/8
# SPOKE-AWS --> Transit GW --> Spoke-AZURE

# AWS - VPC

resource "aws_vpc" "aws_transit_vpc" {
  cidr_block           = "192.168.10.0/24"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "aws-transit-vpc"
  }
}

resource "aws_subnet" "aws_transit_subnet" {
  vpc_id            = aws_vpc.aws_transit_vpc.id
  cidr_block        = "192.168.10.0/28"
  availability_zone = "${var.aws_region}a"


  tags = {
    Name = "aws-transit-subnet"
  }
}

resource "aws_internet_gateway" "transit_gw" {
  vpc_id = aws_vpc.aws_transit_vpc.id
}

resource "aws_route_table" "transit_rt" {
  vpc_id = aws_vpc.aws_transit_vpc.id
  tags = {
    Name = "aviatrix-transit-rt"
  }
}

resource "aws_route" "transit_rt_default" {
  route_table_id         = aws_route_table.transit_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.transit_gw.id
}

resource "aws_route_table_association" "transit_subnet_association" {
  subnet_id      = aws_subnet.aws_transit_subnet.id
  route_table_id = aws_route_table.transit_rt.id
}


# AZURE - VNET

# no need to add 0/0 NH Internet as Azure has it by default 

resource "azurerm_resource_group" "azure_rg" {
  name     = "aviatrix-transit-rg"
  location = var.azure_region
}


resource "azurerm_virtual_network" "azure_transit_vnet" {
  name                = "azure-transit-vnet"
  address_space       = ["192.168.20.0/24"]
  location            = var.azure_region
  resource_group_name = azurerm_resource_group.azure_rg.name

  tags = {
    environment = "transit"
  }
}



resource "azurerm_subnet" "azure_transit_subnet" {
  name                 = "transit-subnet"
  resource_group_name  = azurerm_resource_group.azure_rg.name
  virtual_network_name = azurerm_virtual_network.azure_transit_vnet.name
  address_prefixes     = ["192.168.20.0/28"]
}

# Aviatrix Transit Gateway Module for AWS and Azure

module "aws_transit" {
  source  = "terraform-aviatrix-modules/mc-transit/aviatrix"
  version = "8.0.0"

  cloud            = "AWS"
  region           = var.aws_region
  account          = var.avx_ctrl_account_aws
  use_existing_vpc = true
  vpc_id           = aws_vpc.aws_transit_vpc.id
  gw_subnet        = aws_subnet.aws_transit_subnet.cidr_block
  ha_gw            = false
  depends_on       = [aws_route_table.transit_rt, aws_subnet.aws_transit_subnet, aws_internet_gateway.transit_gw]
}

module "azure_transit" {
  source  = "terraform-aviatrix-modules/mc-transit/aviatrix"
  version = "8.0.0"

  cloud            = "Azure"
  region           = "West Europe"
  account          = var.avx_ctrl_account_azure
  use_existing_vpc = true
  vpc_id           = format("%s:%s:%s", azurerm_virtual_network.azure_transit_vnet.name, azurerm_resource_group.azure_rg.name, azurerm_virtual_network.azure_transit_vnet.guid)
  gw_subnet        = azurerm_subnet.azure_transit_subnet.address_prefixes[0]
  ha_gw            = false
}

# AWS-Azure Transit Peering

resource "aviatrix_transit_gateway_peering" "aws-to-azure-transit-peering" {
  transit_gateway_name1                       = module.aws_transit.transit_gateway.gw_name
  transit_gateway_name2                       = module.azure_transit.transit_gateway.gw_name
  enable_peering_over_private_network         = false
  jumbo_frame                                 = false
  enable_insane_mode_encryption_over_internet = false

}
