resource "azurerm_kubernetes_cluster" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.region
  dns_prefix          = var.name
  default_node_pool {
    name                = var.node_pool_name
    node_count          = var.node_count
    enable_auto_scaling = false
    min_count           = null
    max_count           = null
    vm_size             = var.vm_size
    os_disk_size_gb     = var.disk_size_gb
    vnet_subnet_id      = var.vnet_subnet_id
    tags = {
      SkipGPUDriverInstall = "true"
    }
  }
  identity {
    type = "SystemAssigned"
  }
}