module "subnet_addrs" {
  source          = "hashicorp/subnets/cidr"
  base_cidr_block = var.virtual_network_address_space
  networks = [
    {
      name     = local.public_subnet_identifier
      new_bits = 1
    },
    {
      name     = local.private_subnet_identifier
      new_bits = 1
    }
  ]
}

locals {
  name                      = var.name
  public_subnet_identifier  = "public-subnet"
  public_nsg_identifier     = "public-nsg"
  private_subnet_identifier = "private-subnet"
  private_nsg_identifier    = "private-nsg"
  subnet_details = [
    {
      identifier        = local.public_subnet_identifier
      address_prefix    = module.subnet_addrs.network_cidr_blocks[local.public_subnet_identifier]
      type              = "public"
      service_endpoints = []
      nsg_identifier    = local.public_nsg_identifier
    },
    {
      identifier        = local.private_subnet_identifier
      address_prefix    = module.subnet_addrs.network_cidr_blocks[local.private_subnet_identifier]
      type              = "private"
      service_endpoints = []
      nsg_identifier    = local.private_nsg_identifier
    }
  ]
  network_security_groups = [
    {
      identifier = local.public_nsg_identifier
    },
    {
      identifier = local.private_nsg_identifier
    }
  ]
  network_security_rules = []
  nfs_server = {
    name                   = var.name
    resource_group_name    = module.resource_group.name
    region                 = var.region
    subnet_id              = module.networking.subnet_ids[local.private_subnet_identifier]
    include_public_ip      = false
    size                   = "Standard_B2s"
    zone                   = "1"
    admin_username         = "ubuntu"
    ssh_public_key         = var.ssh_public_key
    accelerated_networking = false
    image_details = {
      publisher = "canonical"
      offer     = "0001-com-ubuntu-server-focal"
      sku       = "20_04-lts-gen2"
      version   = "latest"
    }
    os_disk_details = {
      storage_account_type = "Premium_LRS"
      disk_size_gb         = 1000
    }
    data_disk_details = []
    user_data         = filebase64("${path.module}/user-data/configure-nfs-server.sh")
  }
  aks = {
    name                = var.name
    resource_group_name = module.resource_group.name
    region              = var.region
    node_pool_name      = var.node_pool_name
    node_count          = var.node_count
    disk_size_gb        = 100
    vm_size             = var.vm_size
    vnet_subnet_id      = module.networking.subnet_ids[local.private_subnet_identifier]
  }
  ngc_registry          = "nvcr.io"
  ngc_username          = "$oauthtoken"
  gpu_operator_version  = try(var.gpu_operator_version, "v23.3.2")
  nvidia_driver_version = var.nvidia_driver_version
  nvidia_smi_image      = "nvidia/cuda:11.0.3-base"
}