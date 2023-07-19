#!/bin/bash

set -Ee

function capture_mode() {
  if [[ -z "${1}" ]]; then
    echo -e "Usage: \n bash setup.sh [OPTIONS]\n \n Available Options: \n      install           Install TAO Toolkit API\n      uninstall         Uninstall TAO Toolkit API"
    echo
    exit 1
  fi
}

function get_os() {
  grep -iw ID /etc/os-release | awk -F '=' '{print $2}'
}

function get_os_version() {
  grep -iw VERSION_ID /etc/os-release | awk -F '=' '{print $2}' | tr -d '"'
}

function get_target_os() {
  cat target-os
}

function get_target_os_version() {
  cat target-os-version
}

function check_os_and_version_supported() {
	local os
	os=$(get_os)
	local os_version
	os_version=$(get_os_version)
  if [[ ${os} != "ubuntu" || ! ( ${os_version} == "20.04" || ${os_version} == "18.04" ) ]]; then
    echo "Script cannot be run from a machine running ${os} : ${os_version}"
    exit 1
  fi
}

function check_user_has_password_less_sudo() {
  if ! sudo -n true 2> /dev/null; then
    echo "Script must be run as a user having password-less sudo"
    exit 1
  fi
}

function check_internet_access() {
  if ! wget --quiet --spider www.google.com; then
    echo "This system does not have a internet access"
    exit 1
  fi
}

function tfswitch_install() {
  if ! hash tfswitch 2>/dev/null; then
    echo "Installing tfswitch"
    {
      curl --silent -L https://raw.githubusercontent.com/warrensbox/terraform-switcher/release/install.sh | sudo bash
    } > /dev/null
  fi
}

function terraform_install() {
  if [[ ! -f "${HOME}/bin/terraform" ]] || [[ "$("${HOME}/bin/terraform" --version | head -n 1 | awk '{print $2}')" != "v1.2.4" ]]; then
    echo "Installing terraform"
    {
      if [[ -f "${HOME}/bin/terraform" ]]; then
        rm "${HOME}/bin/terraform"
      fi
      tfswitch 1.2.4
    } > /dev/null
  fi
}

function awscli_install() {
  if ! hash aws 2>/dev/null; then
    echo "Installing awscli"
    {
      rm -f /tmp/awscliv2.zip
      curl --silent "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
      rm -rf /tmp/aws
      if ! hash unzip 2>/dev/null; then
        sudo apt-get -y update
        sudo apt-get -y install unzip
      fi
      unzip /tmp/awscliv2.zip -d /tmp
      sudo /tmp/aws/install
    } > /dev/null
  fi
}

function kubectl_install() {
  if ! hash kubectl 2>/dev/null; then
    echo "Installing kubectl"
    {
      rm -f /tmp/kubectl
      curl --silent -L https://dl.k8s.io/release/v1.23.0/bin/linux/amd64/kubectl -o /tmp/kubectl
      sudo install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl
    } > /dev/null
  fi
}

function jq_install() {
  if ! hash jq 2>/dev/null; then
    echo "Installing jq"
    {
      sudo apt-get -y update
      sudo apt-get -y install jq
    } > /dev/null
  fi
}

function install_local_tools() {
  check_os_and_version_supported
  check_user_has_password_less_sudo
  check_internet_access
  tfswitch_install
  terraform_install
  awscli_install
  kubectl_install
  jq_install
}

function capture_config_in_file() {
  _existing_value="${1}"
  _capture_prompt="${2}"
  _output_format="${3}"
  _output_file="${4}"
  _config_name="${5}"
  _value_prefix="${6}"
  _value_suffix="${7}"
  _description="${8}"
  echo "${_description}"
  local _captured_value
  if [[ -n "${_existing_value}" ]]; then
    read -r -p ">>> ${_capture_prompt} [${_existing_value}]: " _captured_value
    _captured_value="${_captured_value:=${_existing_value}}"
  else
    read -r -p ">>> ${_capture_prompt}: " _captured_value
    if [[ -z "${_captured_value}" ]]; then
      echo "Script requires a ${_config_name} to proceed"
      exit 1
    fi
  fi
  sed -e "/^${_output_format}.*/d" -i "${_output_file}"
  echo "${_output_format}${_value_prefix}${_captured_value}${_value_suffix}" | tee -a "${_output_file}" 1> /dev/null
}

function store_config_in_file() {
  _value="${1}"
  _output_format="${2}"
  _output_file="${3}"
  _value_prefix="${4}"
  _value_suffix="${5}"
  sed -e "/^${_output_format}.*/d" -i "${_output_file}"
  echo "${_output_format}${_value_prefix}${_value}${_value_suffix}" | tee -a "${_output_file}" 1> /dev/null
}

function read_terraform_var() {
  _key="${1}"
  _var_file="${2}"
  grep "^${_key}" "${_var_file}" | awk -F '=' '{print $2}' | sed -e 's|^[[:blank:]]||g' -e 's|[[:blank:]]$||g' | tr -d '"'
}

function capture_cluster_config() {
  touch config.s3.tfbackend
  touch cluster/config.s3.tfbackend
  touch config/config.s3.tfbackend
  touch cluster/variables.auto.tfvars
  touch config/variables.auto.tfvars

  local _existing_state_bucket_name
  _existing_state_bucket_name=$(read_terraform_var 'bucket' config.s3.tfbackend)
  capture_config_in_file "${_existing_state_bucket_name}" "S3 bucket name" "bucket" "config.s3.tfbackend" "S3 bucket name" " = \"" "\"" $'\nPlease provide the name of an existing S3 bucket in your AWS account.\nThis bucket will be used to store metadata about AWS resources that will be created.\nThis bucket is essential to ensure the created resources are destroyed when no longer required.\nNote: You may use the same bucket for multiple deployments.\n'
  _existing_state_bucket_name=$(read_terraform_var 'bucket' config.s3.tfbackend)
  store_config_in_file "${_existing_state_bucket_name}" "bucket" "cluster/config.s3.tfbackend" " = \"" "\""
  store_config_in_file "${_existing_state_bucket_name}" "bucket" "config/config.s3.tfbackend" " = \"" "\""
  store_config_in_file "${_existing_state_bucket_name}" "cluster_state_bucket" "config/variables.auto.tfvars" " = \"" "\""

  local _existing_state_bucket_region
  _existing_state_bucket_region=$(read_terraform_var 'region' config.s3.tfbackend)
  capture_config_in_file "${_existing_state_bucket_region}" "S3 bucket region" "region" "config.s3.tfbackend" "S3 bucket region" " = \"" "\"" $'\nPlease provide the AWS region in which the provided S3 bucket exists.\n'
  _existing_state_bucket_region=$(read_terraform_var 'region' config.s3.tfbackend)
  store_config_in_file "${_existing_state_bucket_region}" "region" "cluster/config.s3.tfbackend" " = \"" "\""
  store_config_in_file "${_existing_state_bucket_region}" "region" "config/config.s3.tfbackend" " = \"" "\""
  store_config_in_file "${_existing_state_bucket_region}" "cluster_state_bucket_region" "config/variables.auto.tfvars" " = \"" "\""

  local _existing_cluster_name
  _existing_cluster_name=$(read_terraform_var 'key' config.s3.tfbackend)
  capture_config_in_file "${_existing_cluster_name}" "Cluster name" "key" "config.s3.tfbackend" "Cluster name" " = \"" "\"" $'\nPlease provide a name to uniquely identify the cluster that will be deployed.\n'
  _existing_cluster_name=$(read_terraform_var 'key' config.s3.tfbackend)
  store_config_in_file "${_existing_cluster_name}" "key" "cluster/config.s3.tfbackend" " = \"" "/cluster/terraform.tfstate\""
  store_config_in_file "${_existing_cluster_name}" "key" "config/config.s3.tfbackend" " = \"" "/config/terraform.tfstate\""
  store_config_in_file "${_existing_cluster_name}" "name" "cluster/variables.auto.tfvars" " = \"" "\""
  store_config_in_file "${_existing_cluster_name}" "name" "config/variables.auto.tfvars" " = \"" "\""
  store_config_in_file "${_existing_cluster_name}" "cluster_state_key" "config/variables.auto.tfvars" " = \"" "/cluster/terraform.tfstate\""

  local _existing_aws_region
  _existing_aws_region=$(read_terraform_var 'aws_region' cluster/variables.auto.tfvars)
  capture_config_in_file "${_existing_aws_region}" "AWS region" "aws_region" "cluster/variables.auto.tfvars" "AWS region" " = \"" "\"" ""

  local _existing_vpc_cidr
  _existing_vpc_cidr=$(read_terraform_var 'vpc_cidr' cluster/variables.auto.tfvars)
  capture_config_in_file "${_existing_vpc_cidr}" "VPC CIDR" "vpc_cidr" "cluster/variables.auto.tfvars" "VPC CIDR" " = \"" "\"" ""

  _current_system_ip="$(curl --silent ifconfig.me)/32"
  store_config_in_file "${_current_system_ip}" "access_cidr_blocks" "cluster/variables.auto.tfvars" " = [\"" "\"]"

  local _existing_ssh_public_key
  _existing_ssh_public_key=$(read_terraform_var 'ssh_public_key' cluster/variables.auto.tfvars)
  capture_config_in_file "${_existing_ssh_public_key}" "Path to SSH public key" "ssh_public_key" "cluster/variables.auto.tfvars" "SSH public key" " = \"" "\"" ""

  local _existing_ngc_api_key
  _existing_ngc_api_key=$(read_terraform_var 'ngc_api_key' config/variables.auto.tfvars)
  capture_config_in_file "${_existing_ngc_api_key}" "NGC API key" "ngc_api_key" "config/variables.auto.tfvars" "NGC API key" " = \"" "\"" ""

  local _existing_ngc_email
  _existing_ngc_email=$(read_terraform_var 'ngc_email' config/variables.auto.tfvars)
  capture_config_in_file "${_existing_ngc_email}" "NGC email" "ngc_email" "config/variables.auto.tfvars" "NGC email" " = \"" "\"" ""

  local _existing_cluster_version
  _existing_cluster_version=$(read_terraform_var 'cluster_version' default-config.tfvars)
  capture_config_in_file "${_existing_cluster_version}" "K8s Cluster Version" "cluster_version" "default-config.tfvars" "K8s Cluster Version" " = \"" "\"" ""
  _existing_cluster_version=$(read_terraform_var 'cluster_version' default-config.tfvars)
  store_config_in_file "${_existing_cluster_version}" "cluster_version" "cluster/variables.auto.tfvars" " = \"" "\""

  local _existing_instance_type
  _existing_instance_type=$(read_terraform_var 'instance_type' default-config.tfvars)
  capture_config_in_file "${_existing_instance_type}" "AWS Instance Type" "instance_type" "default-config.tfvars" "AWS Instance Type" " = \"" "\"" ""
  _existing_instance_type=$(read_terraform_var 'instance_type' default-config.tfvars)
  store_config_in_file "${_existing_instance_type}" "instance_type" "cluster/variables.auto.tfvars" " = \"" "\""

  local _existing_instance_count
  _existing_instance_count=$(read_terraform_var 'instance_count' default-config.tfvars)
  capture_config_in_file "${_existing_instance_count}" "Number of instances of type ${_existing_instance_type}" "instance_count" "default-config.tfvars" "Instance Count" " = \"" "\"" ""
  _existing_instance_count=$(read_terraform_var 'instance_count' default-config.tfvars)
  store_config_in_file "${_existing_instance_count}" "instance_count" "cluster/variables.auto.tfvars" " = \"" "\""

  local _existing_api_chart
  _existing_api_chart=$(read_terraform_var 'api_chart' default-config.tfvars)
  capture_config_in_file "${_existing_api_chart}" "API Chart URL" "api_chart" "default-config.tfvars" "API Chart URL" " = \"" "\"" $'\nPlease provide the URL of the TAO Toolkit API helm chart.\n'
  _existing_api_chart=$(read_terraform_var 'api_chart' default-config.tfvars)
  store_config_in_file "${_existing_api_chart}" "chart" "config/variables.auto.tfvars" " = \"" "\""

  local _existing_api_chart_values_file
  _existing_api_chart_values_file=$(read_terraform_var 'api_values' default-config.tfvars)
  capture_config_in_file "${_existing_api_chart_values_file}" "API Chart Values" "api_values" "default-config.tfvars" "API Chart Values" " = \"" "\"" $'\nPlease provide a helm value file to override any values of the TAO Toolkit API helm chart.\n'
  _absolute_path_of_existing_api_chart_values_file=$(realpath "$(read_terraform_var 'api_values' default-config.tfvars)")
  store_config_in_file "${_absolute_path_of_existing_api_chart_values_file}" "chart_values_file" "config/variables.auto.tfvars" " = \"" "\""

  local _existing_gpu_operator_version
  _existing_gpu_operator_version=$(read_terraform_var 'gpu_operator_version' default-config.tfvars)
  capture_config_in_file "${_existing_gpu_operator_version}" "GPU Operator Version" "gpu_operator_version" "default-config.tfvars" "GPU Operator Version" " = \"" "\"" $'\nPlease provide the Version of the GPU Operator helm chart to use.\n'
  _existing_gpu_operator_version=$(read_terraform_var 'gpu_operator_version' default-config.tfvars)
  store_config_in_file "${_existing_gpu_operator_version}" "gpu_operator_version" "config/variables.auto.tfvars" " = \"" "\""

  local _existing_nvidia_driver_version
  _existing_nvidia_driver_version=$(read_terraform_var 'nvidia_driver_version' default-config.tfvars)
  capture_config_in_file "${_existing_nvidia_driver_version}" "Nvidia Driver Version" "nvidia_driver_version" "default-config.tfvars" "Nvidia Driver Version" " = \"" "\"" $'\nPlease provide the version of Nvidia Driver to install.\n'
  _existing_nvidia_driver_version=$(read_terraform_var 'nvidia_driver_version' default-config.tfvars)
  store_config_in_file "${_existing_nvidia_driver_version}" "nvidia_driver_version" "config/variables.auto.tfvars" " = \"" "\""

  "${HOME}/bin/terraform" -chdir=cluster fmt > /dev/null
  "${HOME}/bin/terraform" -chdir=config fmt > /dev/null
}

function capture_credentials() {
  touch credentials.sh

  local _existing_aws_region
  _existing_aws_region=$(read_terraform_var 'aws_region' cluster/variables.auto.tfvars)
  store_config_in_file "${_existing_aws_region}" "export AWS_REGION=" "credentials.sh" "" "" ""

  local _existing_aws_access_key_id
  _existing_aws_access_key_id=$(grep '^export AWS_ACCESS_KEY_ID=' credentials.sh | awk -F '=' '{print $2}')
  capture_config_in_file "${_existing_aws_access_key_id}" "AWS Access Key ID" "export AWS_ACCESS_KEY_ID=" "credentials.sh" "AWS Access Key ID" "" "" ""

  local _existing_aws_secret_access_key
  _existing_aws_secret_access_key=$(grep '^export AWS_SECRET_ACCESS_KEY=' credentials.sh | awk -F '=' '{print $2}')
  capture_config_in_file "${_existing_aws_secret_access_key}" "AWS Secret Access Key" "export AWS_SECRET_ACCESS_KEY=" "credentials.sh" "AWS Secret Access Key" "" "" ""
}

function terraform_apply() {
  _root_dir="${1}"
  "${HOME}/bin/terraform" -chdir="${_root_dir}" init -reconfigure -backend-config=config.s3.tfbackend
  "${HOME}/bin/terraform" -chdir="${_root_dir}" plan -out=tfplan
  "${HOME}/bin/terraform" -chdir="${_root_dir}" apply tfplan
  rm "${_root_dir}/tfplan"
}

function terraform_destroy() {
  _root_dir="${1}"
  "${HOME}/bin/terraform" -chdir="${_root_dir}" init -reconfigure -backend-config=config.s3.tfbackend
  if [[ "$("${HOME}/bin/terraform" -chdir="${_root_dir}" state list | wc -l)" != "0" ]]; then
    "${HOME}/bin/terraform" -chdir="${_root_dir}" plan -destroy -out=tfplan
    "${HOME}/bin/terraform" -chdir="${_root_dir}" apply tfplan
    rm "${_root_dir}/tfplan"
  fi
}

capture_mode "${@}"
install_local_tools
capture_cluster_config
capture_credentials
if [[ "${1}" == "install" ]]; then
  echo ""
  source ./credentials.sh
  terraform_apply cluster
  terraform_apply config
fi
if [[ "${1}" == "uninstall" ]]; then
  echo ""
  source ./credentials.sh
  terraform_destroy config
  terraform_destroy cluster
fi
