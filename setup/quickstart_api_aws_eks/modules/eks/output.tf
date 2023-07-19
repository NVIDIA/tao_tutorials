output "nodes" {
  value = data.aws_instances.nodes.public_ips
}

output "cluster_name" {
  value = module.eks.cluster_id
}

output "cluster_arn" {
  value = module.eks.cluster_arn
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_ca_certificate" {
  value = base64decode(module.eks.cluster_certificate_authority_data)
}

output "kube_exec_api_version" {
  value = "client.authentication.k8s.io/v1beta1"
}

output "kube_exec_command" {
  value = "aws"
}

output "kube_exec_args" {
  value = [
    "eks",
    "get-token",
    "--region",
    data.aws_region.current.name,
    "--cluster-name",
    module.eks.cluster_id
  ]
}

output "region" {
  value = data.aws_region.current.name
}