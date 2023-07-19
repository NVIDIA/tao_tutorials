resource "kubernetes_namespace_v1" "gpu_operator" {
  metadata {
    annotations = {
      name = "gpu-operator"
    }
    name = "nvidia-gpu-operator"
  }
  depends_on = [module.aks]
}

resource "kubernetes_config_map_v1" "upgrade_gpu_driver" {
  metadata {
    name      = "upgrade-gpu-driver"
    namespace = kubernetes_namespace_v1.gpu_operator.metadata[0].name
    labels = {
      app = "upgrade-gpu-driver"
    }
  }
  data = {
    "upgrade-gpu-driver.sh" = templatefile("${path.module}/user-data/upgrade-gpu-driver.sh.tpl", {
      gpu_operator_version  = local.gpu_operator_version
      nvidia_driver_version = local.nvidia_driver_version == null ? "" : local.nvidia_driver_version
    })
  }
}

resource "kubernetes_daemon_set_v1" "upgrade_gpu_driver" {
  metadata {
    name      = "upgrade-gpu-driver"
    namespace = kubernetes_namespace_v1.gpu_operator.metadata[0].name
    labels = {
      app = "upgrade-gpu-driver"
    }
  }
  spec {
    selector {
      match_labels = {
        app = "upgrade-gpu-driver"
      }
    }
    template {
      metadata {
        labels = {
          app = "upgrade-gpu-driver"
        }
      }
      spec {
        host_pid     = true
        host_network = true
        volume {
          name = "root-mount"
          host_path {
            path = "/"
            type = "DirectoryOrCreate"
          }
        }
        volume {
          name = "entrypoint"
          config_map {
            name         = kubernetes_config_map_v1.upgrade_gpu_driver.metadata[0].name
            default_mode = "0744"
          }
        }
        affinity {
          node_affinity {
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key      = "accelerator"
                  operator = "In"
                  values   = ["nvidia"]
                }
              }
            }
          }
        }
        init_container {
          image   = "ubuntu:20.04"
          name    = "upgrade-gpu-driver"
          command = ["/host/opt/driver-uninstall/upgrade-gpu-driver.sh"]
          env {
            name  = "ROOT_MOUNT_DIR"
            value = "/root"
          }
          security_context {
            privileged = true
          }
          volume_mount {
            mount_path = "/"
            name       = "root-mount"
          }
          volume_mount {
            mount_path = "/host/opt/driver-uninstall"
            name       = "entrypoint"
          }
        }
        container {
          image = "gcr.io/google-containers/pause:2.0"
          name  = "pause"
        }
      }
    }
  }
}

resource "time_sleep" "wait_for_gpu_driver_upgrade" {
  create_duration = "120s"
  depends_on      = [kubernetes_daemon_set_v1.upgrade_gpu_driver]
}

resource "helm_release" "gpu_operator" {
  name            = "gpu-operator"
  repository      = "https://helm.ngc.nvidia.com/nvidia"
  chart           = "gpu-operator"
  version         = local.gpu_operator_version
  namespace       = kubernetes_namespace_v1.gpu_operator.metadata[0].name
  atomic          = true
  cleanup_on_fail = true
  reset_values    = true
  replace         = true
  dynamic "set" {
    for_each = local.nvidia_driver_version == null ? [] : [local.nvidia_driver_version]
    content {
      name  = "driver.version"
      value = set.value
    }
  }
  depends_on = [time_sleep.wait_for_gpu_driver_upgrade]
}

resource "time_sleep" "wait_for_gpu_operator_up" {
  create_duration = "600s"
  depends_on      = [helm_release.gpu_operator]
}

resource "kubernetes_service_v1" "nvidia_smi" {
  metadata {
    name = "nvidia-smi"
  }
  spec {
    type       = "ClusterIP"
    cluster_ip = "None"
  }
  depends_on = [time_sleep.wait_for_gpu_operator_up]
}

resource "kubernetes_stateful_set_v1" "nvidia_smi" {
  metadata {
    labels = {
      k8s-app = "nvidia-smi"
    }
    name = "nvidia-smi"
  }
  spec {
    selector {
      match_labels = {
        k8s-app = "nvidia-smi"
      }
    }
    service_name = kubernetes_service_v1.nvidia_smi.metadata[0].name
    template {
      metadata {
        labels = {
          k8s-app = "nvidia-smi"
        }
      }
      spec {
        container {
          name  = "nvidia-smi"
          image = local.nvidia_smi_image
          args  = ["sleep", "infinity"]
        }
      }
    }
  }
  depends_on = [time_sleep.wait_for_gpu_operator_up]
}