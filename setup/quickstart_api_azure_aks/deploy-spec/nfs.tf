module "nfs_server" {
  source                 = "../modules/linux-virtual-machine"
  name                   = local.nfs_server.name
  resource_group_name    = local.nfs_server.resource_group_name
  region                 = local.nfs_server.region
  subnet_id              = local.nfs_server.subnet_id
  include_public_ip      = local.nfs_server.include_public_ip
  size                   = local.nfs_server.size
  zone                   = local.nfs_server.zone
  user_data              = local.nfs_server.user_data
  admin_username         = local.nfs_server.admin_username
  ssh_public_key         = local.nfs_server.ssh_public_key
  accelerated_networking = local.nfs_server.accelerated_networking
  image_details          = local.nfs_server.image_details
  os_disk_details        = local.nfs_server.os_disk_details
  data_disk_details      = local.nfs_server.data_disk_details
}