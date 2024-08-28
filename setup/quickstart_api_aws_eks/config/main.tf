locals {
  ngc_registry          = "nvcr.io"
  ngc_username          = "$oauthtoken"
  gpu_operator_version  = try(var.gpu_operator_version, "v23.3.2")
  nvidia_driver_version = var.nvidia_driver_version
  nvidia_smi_image      = "nvidia/cuda:11.0.3-base"
}

data "terraform_remote_state" "cluster" {
  backend = "s3"
  config = {
    bucket = var.cluster_state_bucket
    region = var.cluster_state_bucket_region
    key    = var.cluster_state_key
  }
}

data "external" "setup_kube_config" {
  program = ["bash", "${path.module}/utils/setup-kube-config.sh"]
  query = {
    aws_region       = data.terraform_remote_state.cluster.outputs.eks.region
    eks_cluster_name = data.terraform_remote_state.cluster.outputs.eks.cluster_name
    eks_cluster_arn  = data.terraform_remote_state.cluster.outputs.eks.cluster_arn
  }
}

resource "helm_release" "gpu_operator" {
  name             = "gpu-operator"
  repository       = "https://helm.ngc.nvidia.com/nvidia"
  chart            = "gpu-operator"
  version          = local.gpu_operator_version
  namespace        = "nvidia-gpu-operator"
  create_namespace = true
  atomic           = true
  cleanup_on_fail  = true
  reset_values     = true
  replace          = true
  dynamic "set" {
    for_each = local.nvidia_driver_version == null ? [] : [local.nvidia_driver_version]
    content {
      name  = "driver.version"
      value = set.value
    }
  }
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

resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.2.5"
  namespace        = "default"
  create_namespace = true
  atomic           = true
  cleanup_on_fail  = true
  reset_values     = true
  replace          = true
  set {
    name  = "controller.admissionWebhooks.enabled"
    value = "false"
  }
  set {
    name  = "controller.service.type"
    value = try(var.ingress_service_type, "NodePort")
  }
  set {
    name  = "controller.service.nodePorts.http"
    value = "32080"
  }
  set {
    name  = "controller.service.nodePorts.https"
    value = "32443"
  }
}

resource "helm_release" "nfs_subdir_external_provisioner" {
  name             = "nfs-subdir-external-provisioner"
  repository       = "https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner"
  chart            = "nfs-subdir-external-provisioner"
  version          = "4.0.17"
  namespace        = "default"
  create_namespace = true
  atomic           = true
  cleanup_on_fail  = true
  reset_values     = true
  replace          = true
  set {
    name  = "nfs.path"
    value = "/mnt/nfs_share"
  }
  set {
    name  = "nfs.server"
    value = data.terraform_remote_state.cluster.outputs.nfs_server.private_ip
  }
  set {
    name  = "nfs.reclaimPolicy"
    value = "Retain"
  }
  set {
    name  = "storageClass.onDelete"
    value = "retain"
  }
  set {
    name  = "storageClass.pathPattern"
    value = "$${.PVC.namespace}-$${.PVC.name}"
  }
  set {
    name  = "storageClass.reclaimPolicy"
    value = "Retain"
  }
}

resource "kubernetes_secret_v1" "imagepullsecret" {
  metadata {
    name = "imagepullsecret"
  }
  type = "kubernetes.io/dockerconfigjson"
  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        (local.ngc_registry) = {
          "auth" = base64encode("${local.ngc_username}:${var.ngc_api_key}")
        }
      }
    })
  }
}

resource "kubernetes_secret_v1" "bcpclustersecret" {
  metadata {
    name = "bcpclustersecret"
  }
  type = "kubernetes.io/dockerconfigjson"
  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        (local.ngc_registry) = {
          "username" = local.ngc_username
          "password" = var.ngc_api_key
          "email"    = var.ngc_email
          "auth"     = base64encode("${local.ngc_username}:${var.ngc_api_key}")
        }
      }
    })
  }
}

resource "helm_release" "tao_toolkit_api" {
  name                = "tao-api"
  repository          = null
  chart               = var.chart
  version             = null
  namespace           = "default"
  create_namespace    = true
  atomic              = true
  cleanup_on_fail     = true
  reset_values        = true
  replace             = true
  repository_username = local.ngc_username
  repository_password = var.ngc_api_key
  values              = [file(pathexpand(var.chart_values_file))]
  depends_on = [
    kubernetes_secret_v1.imagepullsecret,
    kubernetes_secret_v1.bcpclustersecret,
    time_sleep.wait_for_gpu_operator_up,
    helm_release.ingress_nginx,
    helm_release.nfs_subdir_external_provisioner
  ]
}
