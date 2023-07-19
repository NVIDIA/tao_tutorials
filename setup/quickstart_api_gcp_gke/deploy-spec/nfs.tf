resource "google_service_account" "nfs_server" {
  account_id = local.nfs_server.name
}

module "nfs_server" {
  source                  = "../modules/instance"
  name                    = local.nfs_server.name
  region                  = local.nfs_server.region
  zone                    = local.nfs_server.zone
  network                 = local.nfs_server.network
  subnetwork              = local.nfs_server.subnetwork
  static_public_ip        = local.nfs_server.static_public_ip
  network_interface       = local.nfs_server.network_interface
  tags                    = local.nfs_server.tags
  machine_type            = local.nfs_server.machine_type
  service_account_email   = google_service_account.nfs_server.email
  service_account_scopes  = local.nfs_server.service_account_scopes
  boot_disk               = local.nfs_server.boot_disk
  ssh_public_keys         = local.nfs_server.ssh_public_keys
  ssh_user                = local.nfs_server.ssh_user
  metadata_startup_script = local.nfs_server.metadata_startup_script
}