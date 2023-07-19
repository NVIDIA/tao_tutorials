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
    value = "NodePort"
  }
  set {
    name  = "controller.service.nodePorts.http"
    value = "32080"
  }
  set {
    name  = "controller.service.nodePorts.https"
    value = "32443"
  }
  depends_on = [module.gke]
}

resource "kubernetes_config_map_v1" "install_nfs_common" {
  metadata {
    name = "install-nfs-common"
  }
  data = {
    "install-nfs-common.sh" = file("${path.module}/user-data/install-nfs-common.sh")
  }
  depends_on = [module.gke]
}

resource "kubernetes_daemon_set_v1" "install_nfs_common" {
  metadata {
    name = "install-nfs-common"
    labels = {
      app = "install-nfs-common"
    }
  }
  spec {
    selector {
      match_labels = {
        app = "install-nfs-common"
      }
    }
    template {
      metadata {
        labels = {
          app = "install-nfs-common"
        }
      }
      spec {
        volume {
          name = "root-mount"
          host_path {
            path = "/"
          }
        }
        volume {
          name = "entrypoint"
          config_map {
            name         = kubernetes_config_map_v1.install_nfs_common.metadata[0].name
            default_mode = "0744"
          }
        }
        init_container {
          image   = "ubuntu:20.04"
          name    = "install-nfs-common"
          command = ["/scripts/install-nfs-common.sh"]
          env {
            name  = "ROOT_MOUNT_DIR"
            value = "/root"
          }
          security_context {
            privileged = true
          }
          volume_mount {
            mount_path = "/root"
            name       = "root-mount"
          }
          volume_mount {
            mount_path = "/scripts"
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
    value = module.nfs_server.private_ip
  }
  depends_on = [kubernetes_daemon_set_v1.install_nfs_common]
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
          "username" = local.ngc_username
          "password" = var.ngc_api_key
          "email"    = var.ngc_email
          "auth"     = base64encode("${local.ngc_username}:${var.ngc_api_key}")
        }
      }
    })
  }
  depends_on = [module.gke]
}

resource "helm_release" "tao_toolkit_api" {
  name                = "tao-toolkit-api"
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
  values              = [var.chart_values]
  depends_on = [
    kubernetes_secret_v1.imagepullsecret,
    time_sleep.wait_for_gpu_operator_up,
    helm_release.ingress_nginx,
    helm_release.nfs_subdir_external_provisioner
  ]
}