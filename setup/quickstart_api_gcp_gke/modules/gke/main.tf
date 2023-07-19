resource "google_container_cluster" "this" {
  name           = var.name
  location       = length(var.node_zones) == 1 ? one(var.node_zones) : var.region
  node_locations = length(var.node_zones) > 1 ? var.node_zones : null
  release_channel {
    channel = "STABLE"
  }
  # Default Node Pool is required, to create a cluster, but we need a custom one instead
  # So we delete the default
  remove_default_node_pool = true
  initial_node_count       = 1
  network                  = var.network
  subnetwork               = var.subnetwork
}

resource "google_container_node_pool" "this" {
  name           = format("%s-pool", var.name)
  cluster        = google_container_cluster.this.name
  location       = length(var.node_zones) == 1 ? one(var.node_zones) : var.region
  node_locations = length(var.node_zones) > 1 ? var.node_zones : null
  node_count     = var.node_count
  node_config {
    image_type = "UBUNTU_CONTAINERD"
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/compute"
    ]
    machine_type = var.machine_type
    disk_size_gb = var.disk_size_gb
    disk_type    = var.disk_type
    dynamic "guest_accelerator" {
      for_each = var.gpu_config == null ? [] : [var.gpu_config]
      content {
        type  = guest_accelerator.value["type"]
        count = guest_accelerator.value["count"]
      }
    }
    metadata = {
      disable-legacy-endpoints = "true"
    }
    tags = var.node_tags
  }
  timeouts {
    create = "30m"
    update = "20m"
  }
}
