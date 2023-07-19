locals {
  ubuntu_ami_lookup = {
    owners = ["099720109477"] # Canonical
    filters = [
      {
        name   = "name"
        values = ["ubuntu-eks/k8s_1.23/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
      },
      {
        name   = "virtualization-type"
        values = ["hvm"]
      }
    ]
  }
  no_ami_lookup = {
    owners  = []
    filters = []
  }
  ami_lookup = var.ami_id == "" ? local.ubuntu_ami_lookup : local.no_ami_lookup
  ami_id     = var.ami_id == "" ? data.aws_ami.lookup.id : var.ami_id
}

data "aws_ami" "lookup" {
  most_recent = true
  owners      = local.ami_lookup.owners
  dynamic "filter" {
    for_each = local.ami_lookup.filters
    content {
      name   = filter.value["name"]
      values = filter.value["values"]
    }
  }
}

data "aws_region" "current" {}

module "eks" {
  source                               = "terraform-aws-modules/eks/aws"
  version                              = "18.29.0"
  cluster_name                         = var.name
  cluster_version                      = var.cluster_version
  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = var.api_server_access_cidr_blocks
  create_cloudwatch_log_group          = false
  enable_irsa                          = false
  vpc_id                               = var.vpc_id
  subnet_ids                           = var.subnet_ids
  control_plane_subnet_ids             = var.subnet_ids
  eks_managed_node_groups = {
    ubuntu_20_04 = {
      name                       = var.name
      instance_types             = [var.instance_type]
      min_size                   = 1
      max_size                   = var.instance_count
      desired_size               = var.instance_count
      ami_id                     = data.aws_ami.lookup.id
      ami_type                   = "CUSTOM"
      key_name                   = var.ssh_key
      enable_bootstrap_user_data = true
      post_bootstrap_user_data   = var.additional_user_data
      vpc_security_group_ids     = var.additional_sg_ids
      ebs_optimized              = true
      block_device_mappings = {
        root = {
          device_name = data.aws_ami.lookup.root_device_name
          ebs = {
            volume_size           = 100
            volume_type           = "gp3"
            delete_on_termination = true
          }
        }
      }
    }
  }
}

data "aws_instances" "nodes" {
  filter {
    name   = "tag:aws:autoscaling:groupName"
    values = module.eks.eks_managed_node_groups["ubuntu_20_04"]["node_group_autoscaling_group_names"]
  }
  instance_state_names = ["running"]
}

