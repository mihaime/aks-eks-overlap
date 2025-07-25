# SPOKE-AWS with EKS behind 10/8
# SPOKE-AZURE with AKS behind 10/8
# SPOKE-AWS --> Transit GW --> Spoke-AZURE

# | Purpose            | Subnet CIDR     | Notes                                     |
# | ------------------ | --------------- | ----------------------------------------- |
# | Aviatrix GW subnet | `10.100.0.0/28` | Must be public (0.0.0.0/0 via IGW)        |
# | EKS Node subnet    | `10.100.1.0/24-AZ1, 10.100.9.0/24-AZ2` | Must also have 0.0.0.0/0 for kubelet pull |
# | Internal LB range  | `10.100.2.0/24` | Not explicitly required, but reserve it   |
# | Pod CIDR range     | assigned from Node    |
# | Service CIDR range | default 172.20.0.0/16  - N/A    |
# | AWS SNAT CIDR      | '172.16.10.100` | when AWS communicates to Azure AKS        |

# AWS SPOKE VPC: 10.100.0.0/16

resource "aws_vpc" "aws_spoke_vpc" {
  cidr_block           = "10.100.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "aws-spoke-vpc"
  }
}



resource "aws_subnet" "aws_spoke_gw_subnet" {
  vpc_id                  = aws_vpc.aws_spoke_vpc.id
  cidr_block              = var.aws_spoke_gw_subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags = {
    Name = "spoke-gw-subnet"
  }
}

resource "aws_internet_gateway" "spoke_igw" {
  vpc_id = aws_vpc.aws_spoke_vpc.id
}

resource "aws_route_table" "spoke_rt" {
  vpc_id = aws_vpc.aws_spoke_vpc.id
  tags = {
    Name = "spoke-rt"
  }
}

resource "aws_route" "spoke_rt_default" {
  route_table_id         = aws_route_table.spoke_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.spoke_igw.id
}

resource "aws_route_table_association" "spoke_gw_association" {
  subnet_id      = aws_subnet.aws_spoke_gw_subnet.id
  route_table_id = aws_route_table.spoke_rt.id
}

resource "aws_route_table_association" "eks_node_subnet_assoc_1" {
  subnet_id      = aws_subnet.aws_eks_node_subnet.id
  route_table_id = aws_route_table.spoke_rt.id
}

resource "aws_route_table_association" "eks_node_subnet_assoc_2" {
  subnet_id      = aws_subnet.aws_eks_node_subnet_2.id
  route_table_id = aws_route_table.spoke_rt.id
}


# Aviatrix Spoke Module for AWS
module "aws_spoke" {
  source  = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  version = "8.0.0"

  cloud                            = "AWS"
  region                           = var.aws_region
  account                          = var.avx_ctrl_account_aws
  name                             = "mc-aws-spoke"
  use_existing_vpc                 = true
  vpc_id                           = aws_vpc.aws_spoke_vpc.id
  gw_subnet                        = aws_subnet.aws_spoke_gw_subnet.cidr_block
  ha_gw                            = false
  attached                         = true
  transit_gw                       = module.aws_transit.transit_gateway.gw_name
  included_advertised_spoke_routes = var.aws_snat_vip != "" ? "${var.aws_snat_vip}/32" : ""

  depends_on = [
    aws_subnet.aws_spoke_gw_subnet,
    aws_route_table.spoke_rt
  ]
}


# EKS preparation Subnets 

# EKS Node Subnet
resource "aws_subnet" "aws_eks_node_subnet" {
  vpc_id            = aws_vpc.aws_spoke_vpc.id
  cidr_block        = var.aws_eks_node_subnet_cidr
  availability_zone = "${var.aws_region}a"

  map_public_ip_on_launch = true

  tags = {
    Name = "eks-node-subnet"
  }
}

# Second EKS Node Subnet
resource "aws_subnet" "aws_eks_node_subnet_2" {
  vpc_id            = aws_vpc.aws_spoke_vpc.id
  cidr_block        = "10.100.9.0/24"
  availability_zone = "${var.aws_region}b"

  map_public_ip_on_launch = true

  tags = {
    Name = "eks-node-subnet-2"
  }
}

# NOT USED - JUST IN CASE - Internal LB Subnet
resource "aws_subnet" "aws_internal_lb_subnet" {
  vpc_id            = aws_vpc.aws_spoke_vpc.id
  cidr_block        = var.aws_internal_lb_subnet_cidr
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "internal-lb-subnet"
  }
}

