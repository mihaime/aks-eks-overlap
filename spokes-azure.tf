# SPOKE-AWS with EKS behind 10/8
# SPOKE-AZURE with AKS behind 10/8
# SPOKE-AWS --> Transit GW --> Spoke-AZURE

# Azure SPOKE VNET: 10.100.0.0/16   <- SAME as AWS
# | Purpose            | Subnet CIDR     | Notes                                 |
# | ------------------ | --------------- |----------------------------------------|
# | Aviatrix GW subnet | `10.100.0.0/28` | Must be public (in Azure: 0/0 via IG) |
# | AKS Node subnet    | `10.100.1.0/24-AZ1, 10.100.9.0/24-AZ2` | Node communication, 0/0 needed         |
# | Internal LB range  | `10.100.2.0/24` | For Redis/Postgres LBs (target for DNAT) |
# | Pod CIDR range     | `10.100.4.0/22` | Overlapping with AWS - N/A                 |
# | Service CIDR range | `10.100.8.0/24` | Overlapping with AWS  - N/A            |
# | Azure SNAT VIP     | `172.16.20.100` | Unique VIP for Azure outbound to AWS  |



# Resource Group
resource "azurerm_resource_group" "azure_spoke_rg" {
  name     = "aviatrix-spoke-rg"
  location = var.azure_region
}

# VNET
resource "azurerm_virtual_network" "azure_spoke_vnet" {
  name                = "azure-spoke-vnet"
  address_space       = [var.azure_spoke_vnet_cidr, var.azure_secondary_vnet_cidr]
  location            = var.azure_region
  resource_group_name = azurerm_resource_group.azure_spoke_rg.name

  tags = {
    environment = "spoke"
  }
}

# Subnets
resource "azurerm_subnet" "azure_spoke_gw_subnet" {
  name                 = "spoke-gw-subnet"
  resource_group_name  = azurerm_resource_group.azure_spoke_rg.name
  virtual_network_name = azurerm_virtual_network.azure_spoke_vnet.name
  address_prefixes     = [var.azure_spoke_gw_subnet_cidr]
  depends_on           = [azurerm_virtual_network.azure_spoke_vnet]
}

resource "azurerm_subnet" "azure_aks_node_subnet" {
  name                 = "aks-node-subnet"
  resource_group_name  = azurerm_resource_group.azure_spoke_rg.name
  virtual_network_name = azurerm_virtual_network.azure_spoke_vnet.name
  address_prefixes     = [var.azure_aks_node_subnet_cidr]
  depends_on           = [azurerm_virtual_network.azure_spoke_vnet]
}



resource "azurerm_subnet" "azure_internal_lb_subnet" {
  name                 = "internal-lb-subnet"
  resource_group_name  = azurerm_resource_group.azure_spoke_rg.name
  virtual_network_name = azurerm_virtual_network.azure_spoke_vnet.name
  address_prefixes     = [var.azure_internal_lb_subnet_cidr]
  depends_on           = [azurerm_virtual_network.azure_spoke_vnet]
}


# not needed, seems azure AKS resource creates it when given as param

# resource "azurerm_subnet" "azure_service_subnet" {
#   name                 = "service-subnet"
#   resource_group_name  = azurerm_resource_group.azure_spoke_rg.name
#   virtual_network_name = azurerm_virtual_network.azure_spoke_vnet.name
#   address_prefixes     = [var.azure_service_subnet_cidr]
# }

# Aviatrix Spoke
module "azure_spoke" {
  source  = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  version = "8.0.0"

  cloud                            = "Azure"
  region                           = var.azure_region
  account                          = var.avx_ctrl_account_azure
  name                             = "mc-azure-spoke"
  use_existing_vpc                 = true
  vpc_id                           = format("%s:%s:%s", azurerm_virtual_network.azure_spoke_vnet.name, azurerm_resource_group.azure_spoke_rg.name, azurerm_virtual_network.azure_spoke_vnet.guid)
  gw_subnet                        = azurerm_subnet.azure_spoke_gw_subnet.address_prefixes[0]
  ha_gw                            = false
  attached                         = true
  transit_gw                       = module.azure_transit.transit_gateway.gw_name
  included_advertised_spoke_routes = "${var.azure_redis_avx_vip}/32,${var.azure_postgres_avx_vip}/32"
  depends_on                       = [azurerm_subnet.azure_spoke_gw_subnet, azurerm_subnet.azure_aks_node_subnet, azurerm_subnet.azure_internal_lb_subnet, azurerm_resource_group.azure_spoke_rg, azurerm_virtual_network.azure_spoke_vnet]
}

# ATTACHMENT GIVES CONTEXT DEADLINE EXCEEDED error
# https://aviatrix.atlassian.net/browse/AVX-64714
# timeout of 30 second for attachment
# https://aviatrix.atlassian.net/browse/AVX-64537
