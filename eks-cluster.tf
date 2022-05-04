module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "17.24.0"
  cluster_name    = local.cluster_name
  cluster_version = "1.21"
  subnets         = module.vpc.private_subnets

  tags = {
    ResourceGroup = "apnmt-k8s"
    GithubRepo  = "terraform-aws-eks"
    GithubOrg   = "terraform-aws-modules"
    "karpenter.sh/discovery" = local.cluster_name
  }

  vpc_id = module.vpc.vpc_id

  workers_group_defaults = {
    root_volume_type = "gp2"
  }

  worker_groups = [
    {
      instance_type = "c5.xlarge"
      asg_max_size  = 5
      asg_desired_capacity = 5
    }
  ]
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}
