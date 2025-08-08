# SPOKE-AWS with EKS behind 10/8
# SPOKE-AZURE with AKS behind 10/8
# SPOKE-AWS --> Transit GW --> Spoke-AZURE

# AWS SPOKE VNET: 10.100.0.0/16   <- SAME as AWS

# | Purpose            | Subnet CIDR     | Notes                                     |
# | ------------------ | --------------- | ----------------------------------------- |
# | Aviatrix GW subnet | `10.100.0.0/28` | Must be public (0.0.0.0/0 via IGW)        |
# | EKS Node subnet    | `10.100.1.0/24-AZ1, 10.100.9.0/24-AZ2` | Must also have 0.0.0.0/0 for kubelet pull |
# | Internal LB range  | `10.100.2.0/24` | Not explicitly required, but reserve it   |
# | Pod CIDR range     | assigned from Node    |
# | Service CIDR range | default 172.20.0.0/16  - N/A    |
# | Azure SNAT CIDR      | '172.16.20.100` | when AWS communicates to Azure AKS        |

# internal LB Subnet



resource "azurerm_kubernetes_cluster" "aks_cluster" {
  name                = "aks-cluster"
  location            = var.azure_region
  resource_group_name = azurerm_resource_group.azure_rg.name
  dns_prefix          = "aks"

  default_node_pool {
    name           = "nodepool"
    node_count     = 2
    vm_size        = "Standard_DS2_v2"
    vnet_subnet_id = azurerm_subnet.azure_aks_node_subnet.id
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    service_cidr      = var.azure_service_subnet_cidr # e.g. 10.200.8.0/24
    dns_service_ip    = cidrhost(var.azure_service_subnet_cidr, 10)
    load_balancer_sku = "standard"
  }

  depends_on = [
    azurerm_subnet.azure_aks_node_subnet
  ]
}

# kubeconfig file 
resource "local_file" "aks_kubeconfig" {
  content    = azurerm_kubernetes_cluster.aks_cluster.kube_config_raw
  filename   = "${path.module}/kubeconfig-aks.yaml"
  depends_on = [azurerm_kubernetes_cluster.aks_cluster]
}




####### WITHOUT THIS REDIS AND POSTGRES CANNOT DEPLOY INTERNAL LB AS SERVICE INSIDE THE AKS-NODE-SUBNET ########
# Give AKS permission to modify its internal LB subnet

# Get AKS cluster info
data "azurerm_kubernetes_cluster" "aks_id" {
  name                = azurerm_kubernetes_cluster.aks_cluster.name
  resource_group_name = azurerm_kubernetes_cluster.aks_cluster.resource_group_name
}

# Role assignment: AKS identity → node subnet
resource "azurerm_role_assignment" "aks_node_subnet_contributor" {
  scope                = azurerm_subnet.azure_aks_node_subnet.id
  role_definition_name = "Network Contributor"
  principal_id         = data.azurerm_kubernetes_cluster.aks_id.identity[0].principal_id

  depends_on = [
    azurerm_kubernetes_cluster.aks_cluster,
    azurerm_subnet.azure_aks_node_subnet,
  ]
}


# Role assignment: AKS identity → internal LB subnet
resource "azurerm_role_assignment" "aks_internal_lb_subnet_contributor" {
  scope                = azurerm_subnet.azure_internal_lb_subnet.id
  role_definition_name = "Network Contributor"
  principal_id         = data.azurerm_kubernetes_cluster.aks_id.identity[0].principal_id

  depends_on = [
    azurerm_kubernetes_cluster.aks_cluster,
    azurerm_subnet.azure_internal_lb_subnet,
  ]
}
############   END PERMISSIONS #################################################################################

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.aks_cluster.name
}

output "aks_fqdn" {
  value = azurerm_kubernetes_cluster.aks_cluster.fqdn
}
