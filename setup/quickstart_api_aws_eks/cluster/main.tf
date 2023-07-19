locals {
  nfs_server_ami_lookup = {
    owners = ["099720109477"] # Canonical
    filters = [
      {
        name   = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
      },
      {
        name   = "virtualization-type"
        values = ["hvm"]
      }
    ]
  }
}

module "networking" {
  source              = "../modules/networking"
  cidr_block          = var.vpc_cidr
  vpc_name            = var.name
  public_subnet_names = [for i in range(1, 3) : format("%s-public-%s", var.name, i)]
}

module "keypair" {
  source     = "../modules/keypair"
  key_name   = var.name
  public_key = file(pathexpand(var.ssh_public_key))
}

module "nfs_client_security_group" {
  source = "../modules/security-group"
  name   = format("%s-nfs-client", var.name)
  vpc_id = module.networking.vpc_id
  ingress_rules = [
    {
      description      = "nfs client access"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = []
      ipv6_cidr_blocks = []
      security_groups  = []
      self             = true
    }
  ]
}

module "eks_node_security_group" {
  source = "../modules/security-group"
  name   = format("%s-node-access", var.name)
  vpc_id = module.networking.vpc_id
  ingress_rules = [
    {
      description      = "ssh access"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = var.access_cidr_blocks
      ipv6_cidr_blocks = []
      security_groups  = []
      self             = true
    },
    {
      description      = "ingress http access"
      from_port        = 32080
      to_port          = 32080
      protocol         = "tcp"
      cidr_blocks      = var.access_cidr_blocks
      ipv6_cidr_blocks = []
      security_groups  = []
      self             = true
    },
    {
      description      = "ingress https access"
      from_port        = 32443
      to_port          = 32443
      protocol         = "tcp"
      cidr_blocks      = var.access_cidr_blocks
      ipv6_cidr_blocks = []
      security_groups  = []
      self             = true
    }
  ]
}

module "nfs_server" {
  source                = "../modules/ec2"
  instance_type         = "t3.micro"
  instance_name         = format("%s-nfs-server", var.name)
  ami_lookup            = local.nfs_server_ami_lookup
  ec2_key               = module.keypair.name
  root_volume_size      = 1000
  root_volume_type      = "gp3"
  instance_profile_name = ""
  subnet_id             = element(module.networking.public_subnet_ids, 0)
  vpc_id                = module.networking.vpc_id
  user_data             = file("${path.module}/user-data/install-nfs-server.sh")
  additional_sg_ids = [
    module.nfs_client_security_group.security_group_id
  ]
  include_public_ip = false
}

module "eks" {
  source                        = "../modules/eks"
  name                          = var.name
  vpc_id                        = module.networking.vpc_id
  subnet_ids                    = module.networking.public_subnet_ids
  instance_type                 = var.instance_type
  instance_count                = var.instance_count
  ssh_key                       = module.keypair.name
  api_server_access_cidr_blocks = var.access_cidr_blocks
  additional_user_data          = file("${path.module}/user-data/install-nfs-common.sh")
  additional_sg_ids = [
    module.nfs_client_security_group.security_group_id,
    module.eks_node_security_group.security_group_id
  ]
}
