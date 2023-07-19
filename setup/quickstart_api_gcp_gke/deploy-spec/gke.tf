module "gke" {
  source       = "../modules/gke"
  name         = local.gke_node.name
  region       = local.gke_node.region
  node_zones   = local.gke_node.node_zones
  network      = local.gke_node.network
  subnetwork   = local.gke_node.subnetwork
  node_count   = local.gke_node.node_count
  machine_type = local.gke_node.machine_type
  disk_size_gb = local.gke_node.disk.size_gb
  disk_type    = local.gke_node.disk.type
  node_tags    = local.gke_node.tags
  gpu_config   = local.gke_node.gpu_config
}