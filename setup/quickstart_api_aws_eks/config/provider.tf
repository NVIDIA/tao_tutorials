provider "kubernetes" {
  host                   = data.terraform_remote_state.cluster.outputs.eks.cluster_endpoint
  cluster_ca_certificate = data.terraform_remote_state.cluster.outputs.eks.cluster_ca_certificate
  exec {
    api_version = data.terraform_remote_state.cluster.outputs.eks.kube_exec_api_version
    command     = data.terraform_remote_state.cluster.outputs.eks.kube_exec_command
    args        = data.terraform_remote_state.cluster.outputs.eks.kube_exec_args
  }
}

provider "helm" {
  kubernetes {
    host                   = data.terraform_remote_state.cluster.outputs.eks.cluster_endpoint
    cluster_ca_certificate = data.terraform_remote_state.cluster.outputs.eks.cluster_ca_certificate
    exec {
      api_version = data.terraform_remote_state.cluster.outputs.eks.kube_exec_api_version
      command     = data.terraform_remote_state.cluster.outputs.eks.kube_exec_command
      args        = data.terraform_remote_state.cluster.outputs.eks.kube_exec_args
    }
  }
}