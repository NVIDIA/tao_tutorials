#!/bin/bash

eval "$(jq -r '@sh "_aws_profile=\(.aws_profile) _aws_region=\(.aws_region) _eks_cluster_name=\(.eks_cluster_name) _eks_cluster_arn=\(.eks_cluster_arn)"')"

if aws eks update-kubeconfig --region "${_aws_region}" --name "${_eks_cluster_name}" 1> /dev/null 2>&1; then
  jq -n --arg command_to_use "kubectl config use-context ${_eks_cluster_arn}" '{"status":"success","commandToUse":$command_to_use}'
else
  jq -n '{"status":"failure"}'
fi