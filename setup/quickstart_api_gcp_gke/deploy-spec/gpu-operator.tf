resource "kubernetes_namespace_v1" "gpu_operator" {
  metadata {
    annotations = {
      name = "gpu-operator"
    }
    name = "nvidia-gpu-operator"
  }
  depends_on = [module.gke]
}

resource "kubernetes_resource_quota_v1" "gpu_operator_quota" {
  metadata {
    name      = "gpu-operator-quota"
    namespace = kubernetes_namespace_v1.gpu_operator.metadata[0].name
  }
  spec {
    hard = {
      pods = 100
    }
    scope_selector {
      match_expression {
        operator   = "In"
        scope_name = "PriorityClass"
        values     = ["system-node-critical", "system-cluster-critical"]
      }
    }
  }
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
  depends_on = [kubernetes_resource_quota_v1.gpu_operator_quota]
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