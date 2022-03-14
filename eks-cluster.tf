provider "kubernetes" {
  host = data.aws_eks_cluster.myapp_cluster.endpoint
  token = data.aws_eks_cluster_auth.myapp_cluster.token
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.myapp_cluster.certificate_authority.0.data)
}

data "aws_eks_cluster" "myapp_cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "myapp_cluster" {
  name = module.eks.cluster_id
}


###Define EKS cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "18.10.0"
 
  cluster_name = "myapp-cluster"
  cluster_version = "1.21"
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  cluster_addons = {
    coredns = {
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {}
    vpc-cni = {
      resolve_conflicts = "OVERWRITE"
    }
  }

  ###Using VPS subnets
  subnet_ids = module.vpc.private_subnets
  vpc_id = module.vpc.vpc_id
  
  tags = {
      environment = "development"
      application = "myapp"
  }
  
  self_managed_node_group_defaults = {
    instance_type                          = "t2.micro"
    update_launch_template_default_version = true
    iam_role_additional_policies           = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
  }

self_managed_node_groups = {
    one = {
      name = "group1"

      public_ip    = true
      max_size     = 3
      desired_size = 2

      use_mixed_instances_policy = false
    }
    two = {
      name = "group1"

      public_ip    = true
      max_size     = 3
      desired_size = 2

      use_mixed_instances_policy = false
    }
   }
}