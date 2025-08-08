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
# | AWS SNAT CIDR      | '172.16.10.100` | when AWS communicates to Azure AKS        |


module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = "eks-cluster"
  cluster_version = "1.33"

  cluster_endpoint_public_access = true
  # Optional: Adds the current caller identity as an administrator via cluster access entry
  enable_cluster_creator_admin_permissions = true

  vpc_id = aws_vpc.aws_spoke_vpc.id
  subnet_ids = [
    aws_subnet.aws_eks_node_subnet.id,
    aws_subnet.aws_eks_node_subnet_2.id
  ]
  eks_managed_node_groups = {
    default = {
      instance_types = ["t3.medium"]
      min_size     = 1
      max_size       = 4
      desired_size   = 2
    }
  }
}

## WITH NLB I had 3 connections working, 2 stalling, TCP reuse and stuff => switch to ALB


# 🛠️ Automatically generate kubeconfig-eks.yaml
resource "null_resource" "generate_kubeconfig" {
  depends_on = [module.eks]

  provisioner "local-exec" {
    command = <<EOT
aws eks update-kubeconfig \
  --region ${var.aws_region} \
  --name ${module.eks.cluster_name} \
  --kubeconfig ${path.module}/kubeconfig-eks.yaml
EOT
  }
}



output "eks_cluster_name" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_name
}

output "eks_fqdn" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}



