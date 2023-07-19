provider "google" {
  project     = var.provider_config.project
  credentials = var.provider_config.credentials
}

provider "kubernetes" {
  token                  = data.google_client_config.this.access_token
  host                   = format("https://%s", module.gke.endpoint)
  cluster_ca_certificate = module.gke.cluster_ca_certificate
}

provider "helm" {
  kubernetes {
    token                  = data.google_client_config.this.access_token
    host                   = format("https://%s", module.gke.endpoint)
    cluster_ca_certificate = module.gke.cluster_ca_certificate
  }
}
