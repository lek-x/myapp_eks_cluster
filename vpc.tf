provider "aws" {
	region = var.region
}

##Get data of AZS from AWS
data "aws_availability_zones" "azs" {}


#Define VPC 
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.13.0"


  name = "vpc1"
  cidr = var.vpc_cidr_block
  private_subnets = var.private_subnets_cidr_blocks
  public_subnets = var.public_subnets_cidr_blocks
  azs = data.aws_availability_zones.azs.names

  #Enable NAT and DNS
  enable_nat_gateway = true
  single_nat_gateway = true
  enable_dns_hostnames = true

  tags = {
   "kubernetes.io/cluster/myapp-cluster" = "shared"
  }

  private_subnet_tags = {
   "kubernetes.io/cluster/myapp-cluster" = "shared"
   "kubernetes.io/role/internal-elb" = 1
  }

  public_subnet_tags = {
   "kubernetes.io/cluster/myapp-cluster" = "shared"
   "kubernetes.io/role/elb" = 1
  } 
}


resource "aws_security_group" "additional" {
  name_prefix = "myapp-cluster-additional"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = [
      "10.0.0.0/8",
      "172.16.0.0/12",
      "192.168.0.0/16",
    ]
  }


}

resource "aws_kms_key" "eks" {
  description             = "EKS Secret Encryption Key"
  deletion_window_in_days = 7
  enable_key_rotation     = true

}

data "aws_ami" "eks_default" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amazon-eks-node-1.21-v*"]
  }
}
