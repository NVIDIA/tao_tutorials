data "google_client_config" "this" {}

module "subnet_addrs" {
  source          = "hashicorp/subnets/cidr"
  base_cidr_block = var.network_cidr_range
  networks = [
    {
      name     = local.gke_subnet_name
      new_bits = 1
    },
    {
      name     = local.nfs_subnet_name
      new_bits = 1
    }
  ]
}

locals {
  name            = var.name
  gke_subnet_name = "gke"
  nfs_subnet_name = "nfs"
  region          = var.region
  zone            = var.zone
  gke_node_tags   = [format("%s-gke-node", local.name)]
  nfs_node_tags   = [format("%s-nfs-node", local.name)]
  networking = {
    name   = local.name
    region = local.region
    subnets = [
      {
        name                     = local.gke_subnet_name
        ip_cidr_range            = module.subnet_addrs.network_cidr_blocks[local.gke_subnet_name]
        private_ip_google_access = true
        private                  = false
      },
      {
        name                     = local.nfs_subnet_name
        ip_cidr_range            = module.subnet_addrs.network_cidr_blocks[local.nfs_subnet_name]
        private_ip_google_access = true
        private                  = true
      }
    ]
    router_bgp = {
      advertise_mode     = "CUSTOM"
      advertised_groups  = []
      asn                = 16550
      keepalive_interval = 20
    }
    firewalls = [
      {
        name     = format("%s-ssh-access", local.name)
        priority = 1000
        allow = [
          {
            protocol = "tcp"
            ports    = [22]
          }
        ]
        nat_source    = false
        source_ranges = ["35.235.240.0/20"]
        source_tags   = []
        target_tags   = concat(local.gke_node_tags, local.nfs_node_tags)
      },
      {
        name     = format("%s-nfs-access", local.name)
        priority = 1000
        allow = [
          {
            protocol = "tcp"
            ports    = ["1-65535"]
          },
          {
            protocol = "udp"
            ports    = ["1-65535"]
          }
        ]
        nat_source    = false
        source_ranges = []
        source_tags   = concat(local.gke_node_tags, local.nfs_node_tags)
        target_tags   = local.nfs_node_tags
      }
    ]
  }
  nfs_server = {
    name       = format("%s-nfs", local.name)
    region     = local.region
    zone       = local.zone
    network    = module.networking.network_name
    subnetwork = module.networking.subnetworks[local.nfs_subnet_name].name
    network_interface = {
      access_configs = [
        {
          network_tier = "PREMIUM"
        }
      ]
    }
    tags         = local.nfs_node_tags
    machine_type = "e2-medium"
    service_account_scopes = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/trace.append"
    ]
    boot_disk = {
      device_name  = format("%s-boot", local.name)
      size_gb      = 1000
      source_image = "projects/ubuntu-os-cloud/global/images/ubuntu-2004-focal-v20221018"
      type         = "pd-balanced"
      auto_delete  = true
    }
    ssh_public_keys         = []
    ssh_user                = "ubuntu"
    metadata_startup_script = file("${path.module}/user-data/configure-nfs-server.sh")
    static_public_ip        = true
  }
  gke_node = {
    name         = local.name
    region       = local.region
    node_zones   = [local.zone]
    network      = module.networking.network_name
    subnetwork   = module.networking.subnetworks[local.gke_subnet_name].name
    tags         = local.gke_node_tags
    machine_type = var.machine_type
    disk = {
      size_gb = 100
      type    = "pd-balanced"
    }
    node_count = var.node_count
    gpu_config = var.gpu_type != null && var.gpu_type != "" ? {
      type  = var.gpu_type
      count = try(var.gpu_count, 1)
    } : null
  }
  ngc_registry          = "nvcr.io"
  ngc_username          = "$oauthtoken"
  gpu_operator_version  = try(var.gpu_operator_version, "v23.3.2")
  nvidia_driver_version = var.nvidia_driver_version
  nvidia_smi_image      = "nvidia/cuda:11.0.3-base"
}