provider "azurerm" {
  tenant_id       = var.provider_config.tenant_id
  subscription_id = var.provider_config.subscription_id
  client_id       = var.provider_config.client_id
  client_secret   = var.provider_config.client_secret
  features {}
}

provider "kubernetes" {
  host                   = module.aks.kube_config.host
  client_certificate     = module.aks.kube_config.client_certificate
  client_key             = module.aks.kube_config.client_key
  cluster_ca_certificate = module.aks.kube_config.cluster_ca_certificate
}

provider "helm" {
  kubernetes {
    host                   = module.aks.kube_config.host
    client_certificate     = module.aks.kube_config.client_certificate
    client_key             = module.aks.kube_config.client_key
    cluster_ca_certificate = module.aks.kube_config.cluster_ca_certificate
  }
}
