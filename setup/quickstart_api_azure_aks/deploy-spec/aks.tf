module "aks" {
  source              = "../modules/aks"
  name                = local.aks.name
  resource_group_name = local.aks.resource_group_name
  region              = local.aks.region
  node_pool_name      = local.aks.node_pool_name
  node_count          = local.aks.node_count
  disk_size_gb        = local.aks.disk_size_gb
  vm_size             = local.aks.vm_size
  vnet_subnet_id      = local.aks.vnet_subnet_id
}