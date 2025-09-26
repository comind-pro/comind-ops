# ====================================================
# SHARED INFRASTRUCTURE
# ====================================================

module "shared" {
  source = "../../modules/shared"
  
  cluster_type = var.cluster_type
  cluster_name = var.cluster_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
  tags         = var.tags
}

# ====================================================
# EKS CLUSTER
# ====================================================

module "eks" {
  source = "../../modules/eks"
  
  cluster_name           = var.cluster_name
  kubernetes_version     = var.kubernetes_version
  subnet_ids             = concat(module.shared.public_subnet_ids, module.shared.private_subnet_ids)
  private_subnet_ids     = module.shared.private_subnet_ids
  aws_region            = var.aws_region
  node_group_desired_size = var.node_group_desired_size
  node_group_max_size    = var.node_group_max_size
  node_group_min_size    = var.node_group_min_size
  tags                   = var.tags
  
  depends_on = [module.shared]
}
