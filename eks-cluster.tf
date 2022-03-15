data "aws_caller_identity" "current" {}

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
  cluster_encryption_config = [{
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }]
  ###Using VPS subnets
  subnet_ids = module.vpc.private_subnets
  vpc_id = module.vpc.vpc_id
  
  tags = {
      environment = "development"
      application = "myapp"
  }

   # Extend node-to-node security group rules
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  
  ###Deifne defaults settings for our groups
  self_managed_node_group_defaults = {
    instance_type                          = "t2.micro"
    update_launch_template_default_version = true
    iam_role_additional_policies           = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
  }

###Define groups
self_managed_node_groups = {
    one = {
      name = "group1"

      public_ip    = true
      max_size     = 3
      desired_size = 2

      use_mixed_instances_policy = false
    }
    two = {
      name = "group2"

      public_ip    = true
      max_size     = 3
      desired_size = 2

      use_mixed_instances_policy = false
    }
   }
 }
} 
  data "aws_eks_cluster_auth" "this" {
    name = module.eks.cluster_id
}

  locals {
    kubeconfig = yamlencode({
      apiVersion      = "v1"
      kind            = "Config"
      current-context = "terraform"
      clusters = [{
        name = module.eks.cluster_id
        cluster = {
          certificate-authority-data = module.eks.cluster_certificate_authority_data
          server                     = module.eks.cluster_endpoint
        }
      }]
      contexts = [{
        name = "terraform"
        context = {
          cluster = module.eks.cluster_id
          user    = "terraform"
        }
      }]
      users = [{
        name = "terraform"
        user = {
          token = data.aws_eks_cluster_auth.this.token
        }
      }]
    })
  }
  
  resource "null_resource" "apply" {
    triggers = {
      kubeconfig = base64encode(local.kubeconfig)
      cmd_patch  = <<-EOT
        kubectl create configmap aws-auth -n kube-system --kubeconfig <(echo $KUBECONFIG | base64 --decode)
        kubectl patch configmap/aws-auth --patch "${module.eks.aws_auth_configmap_yaml}" -n kube-system --kubeconfig <(echo $KUBECONFIG | base64 --decode)
      EOT
    }
  
    provisioner "local-exec" {
      interpreter = ["/bin/bash", "-c"]
      environment = {
        KUBECONFIG = self.triggers.kubeconfig
      }
      command = self.triggers.cmd_patch
    }
  }
