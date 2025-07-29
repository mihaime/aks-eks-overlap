## BUG IN AVIATRIX TERRAFORM 8.0 ## 
## https://aviatrix.atlassian.net/browse/AVX-64737

# # # AWS side represented to Azure 
# variable "aws_snat_vip" {
#   type    = string
#   default = "172.16.10.100"
# }

# # Azure side represented to AWS
# variable "azure_snat_vip" {
#   type    = string
#   default = "172.16.20.100"
# }

## FLOW:
## AWS-SPOKE: included adv cidr 172.16.10.100
##  Web app: 10.100.x.y -> VIP REDIS/POSTGRES (172.20.20.100/101) --> out eth0 AWS SPOKE -> SNAT to aws_snat_vip
## Azure-Spoke: included adv cidr 172.16.20.100/101 
##  Postgres/Redis: DNAT SRC VIP WebApp (aws_snat_vip) -> DST: AZURE_VIP_POSTGRES/REDIS -> DNAT TO: POSTGRES/REDIS LBIP
## + port Postgres 5432, Redis 6379


#################### AWS #####################################

# SNAT AWS traffic to VIP when going to Azure and Overlapping

resource "aviatrix_gateway_snat" "aws_eks_to_azure_postgres_redis" {
  gw_name   = module.aws_spoke.spoke_gateway.gw_name
  snat_mode = "customized_snat"


  snat_policy {
    src_cidr   = aws_vpc.aws_spoke_vpc.cidr_block # AWS EKS pod/service range
    dst_cidr   = "${var.azure_redis_avx_vip}/32"  # VIP for Azure internal LB
    dst_port   = 6379                             # Redis port
    protocol   = "tcp"
    interface  = "eth0" # leave empty for default
    connection = module.aws_transit.transit_gateway.gw_name
    snat_ips   = var.aws_snat_vip
  }

}


#################### END AWS #####################################

#################### AZURE #####################################


resource "aviatrix_gateway_dnat" "aws_eks_to_azure_postgres_redis" {
  gw_name = module.azure_spoke.spoke_gateway.gw_name

  dnat_policy {
    src_cidr   = "${var.aws_snat_vip}/32"           # AWS EKS pod/service range
    dst_cidr   = "${var.azure_postgres_avx_vip}/32" # VIP for Azure internal LB
    dst_port   = 5432                               # Postgres port
    protocol   = "tcp"
    connection = module.azure_transit.transit_gateway.gw_name
    mark       = "65535"
    dnat_ips   = var.azure_redis_lbip
  }

  dnat_policy {
    src_cidr   = "${var.aws_snat_vip}/32"        # AWS EKS pod/service range
    dst_cidr   = "${var.azure_redis_avx_vip}/32" # VIP for Azure internal LB
    dst_port   = 6379                            # Postgres port
    protocol   = "tcp"
    connection = module.azure_transit.transit_gateway.gw_name
    mark       = "65536"
    dnat_ips   = var.azure_postgres_lbip
  }

}

resource "aviatrix_gateway_snat" "aws_to_azure_postgres_redis_snat_gw_ip" {
  gw_name   = module.aws_spoke.spoke_gateway.gw_name
  snat_mode = "customized_snat"
  snat_policy {
    protocol   = "all"
    interface  = "eth0"
    connection = "None"
    mark       = "65535"
    snat_ips   = module.azure_spoke.spoke_gateway.private_ip
  }

  snat_policy {
    protocol   = "all"
    interface  = "eth0"
    connection = "None"
    mark       = "65536"
    snat_ips   = module.azure_spoke.spoke_gateway.private_ip
  }
}


#################### END AZURE #####################################
