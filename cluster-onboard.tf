## HERE I JUST NEEDED TO ADD THE RIGHTS IN AZURE PORTAL
## FOR LIST CLUSTERS & co, see the README.md file

resource "aviatrix_kubernetes_cluster" "aks" {
  cluster_id          = lower(data.azurerm_kubernetes_cluster.aks.id)
  use_csp_credentials = true
}

## THIS one was erroring out and I needed more rights, see below

resource "aviatrix_kubernetes_cluster" "eks" {
  cluster_id          = module.eks.cluster_arn
  use_csp_credentials = true
}

############################################
# EKS Access for Aviatrix Controller
############################################

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Create EKS access entry for Aviatrix role
resource "aws_eks_access_entry" "aviatrix" {
  cluster_name      = module.eks.cluster_name
  principal_arn     = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aviatrix-role-app"
  kubernetes_groups = ["view-nodes"]
  type              = "STANDARD"
}

# Attach AmazonEKSViewPolicy for cluster-wide view
resource "aws_eks_access_policy_association" "aviatrix" {
  cluster_name  = module.eks.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
  principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aviatrix-role-app"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.aviatrix]
}

# Create a Kubernetes ClusterRole to allow "view-nodes" group to view nodes
resource "kubernetes_cluster_role" "aviatrix_view_nodes" {
  provider = kubernetes.eks
  depends_on = [null_resource.generate_kubeconfig]
  metadata {
    name = "view-nodes"
  }

  rule {
    verbs      = ["get", "list", "watch"]
    api_groups = [""]
    resources  = ["nodes"]
  }
}

# Bind the ClusterRole to the "view-nodes" group used by Aviatrix
resource "kubernetes_cluster_role_binding" "aviatrix_view_nodes" {
  provider = kubernetes.eks
  depends_on = [null_resource.generate_kubeconfig]
  metadata {
    name = "view-nodes"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.aviatrix_view_nodes.metadata[0].name
  }

  subject {
    kind      = "Group"
    name      = "view-nodes"
    api_group = "rbac.authorization.k8s.io"
  }
}
