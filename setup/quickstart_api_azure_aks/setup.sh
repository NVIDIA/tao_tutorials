#!/bin/bash

set -Ee

function capture_mode() {
  _allowed_modes=("install" "uninstall")
  if [[ -z "${1}" ]] || [[ "$(echo "${_allowed_modes[@]}" | grep -w "${1}" -c)" == 0 ]]; then
    echo "Usage:"
    echo "  ./setup.sh [OPTIONS]"
    echo ""
    echo "  Available Options:"
    echo "      install                 Install/update TAO infrastructure and application."
    echo "      uninstall               Uninstall TAO application and infrastructure."
    echo ""
    echo "NOTE: Ensure you have reviewed deploy.yml before running install."
    echo ""
    exit 1
  fi
}

function log_operation() {
  _mode="${1}"
  mkdir -p logs
  echo "$(date --iso-8601=seconds) [INFO] Attempting to ${_mode} with config > $(cat deploy.yml | base64 -w 0)" >> "logs/$(date --iso-8601).log"
}

function get_os() {
  grep -iw ID /etc/os-release | awk -F '=' '{print $2}'
}

function get_os_version() {
  grep -iw VERSION_ID /etc/os-release | awk -F '=' '{print $2}' | tr -d '"'
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

function az_install() {
  if ! hash az 2>/dev/null; then
    echo "Installing az"
    {
      curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
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

function yq_install() {
  if ! hash yq 2>/dev/null; then
    echo "Installing yq"
    {
      rm -f /tmp/yq
      curl --silent -L https://github.com/mikefarah/yq/releases/download/v4.30.5/yq_linux_amd64 -o /tmp/yq
      sudo install -o root -g root -m 0755 /tmp/yq /usr/local/bin/yq
    } > /dev/null
  elif [[ "$(yq --version | awk '{print $2}')" != "(https://github.com/mikefarah/yq/)" ]] || [[ "$(yq --version | awk 'NF>1{print $NF}' | tr -d 'v' | cut -d '.' -f 1)" -lt 4 ]] || [[ "$(yq --version | awk 'NF>1{print $NF}' | tr -d 'v' | cut -d '.' -f 2)" -lt 30 ]]; then
    echo "Installing yq"
    {
      sudo rm -f "$(which yq)"
      rm -f /tmp/yq
      curl --silent -L https://github.com/mikefarah/yq/releases/download/v4.30.5/yq_linux_amd64 -o /tmp/yq
      sudo install -o root -g root -m 0755 /tmp/yq /usr/local/bin/yq
    } > /dev/null
  fi
}

function install_local_tools() {
  check_os_and_version_supported
  check_user_has_password_less_sudo
  check_internet_access
  tfswitch_install
  terraform_install
  az_install
  kubectl_install
  jq_install
  yq_install
}

function deploy_dir() {
  echo "deploy"
}

function name() {
  yq eval ".name" deploy.yml
}

function backend_key() {
  echo "$(name)/terraform.tfstate"
}

function check_names(){
  _name_regex="^[a-z0-9][a-z0-9-]*[a-z0-9]+$"

  _name_format_message=" - Allowed characters:"
  _name_format_message+="\n   * Lower case alphabet characters"
  _name_format_message+="\n   * Numeric characters"
  _name_format_message+="\n   * Hyphen (-)"
  _name_format_message+="\n - Cannot end with hyphen (-)"
  _name_format_message+="\n"
  _length_constraint_message_template=" - Length limitations:"
  _length_constraint_message_template+="\n   * Total length cannot exceed %d characters"
  _length_constraint_message_template+="\n"
  _name=$(name)

  if ! [[ "${_name}" =~ ${_name_regex} ]]; then
    echo "Invalid value found for name ${_name}"
    printf '%s'"${_name_format_message}"
    exit 1
  elif [[ "$(echo -n "${_name}" | wc -c)" -gt 28 ]]; then
    echo "Invalid value found for name ${_name}"
    printf "${_length_constraint_message_template}" 28
    exit 1
  fi
}

function validate_deploy_config() {
  check_names
}

function prepare_backend_config() {
  yq eval '.backend' deploy.yml -o=json | jq --arg key "$(backend_key)" '. += { key: ($key + "") }'
}

function prepare_variables_config() {
  yq eval '.spec' deploy.yml -o=json | \
    jq \
      --argjson provider "$(yq eval '.provider' deploy.yml -o=json)" \
      --arg name "$(name)" \
      '. += {name: $name} | . += {provider_config: $provider}'
}

function prepare_deploy_dir() {
  rm -rf "$(deploy_dir)"

  validate_deploy_config

  cp -r "deploy-spec" "$(deploy_dir)"

  _backend_file="$(deploy_dir)/tf-backend.json"
  prepare_backend_config > "${_backend_file}"

  _variables_file="$(deploy_dir)/tf-variables.json"
  prepare_variables_config > "${_variables_file}"
}

function confirmation_prompt() {
  local _prompt_message
  if [ "$1" ];
  then
    _prompt_message="$1"
  else
    _prompt_message="Are you sure you want to continue"
  fi
  _prompt_message="$_prompt_message [y/n] ?"
  while true;
  do
    read -r -p "$_prompt_message" _prompt_response
    case "$_prompt_response" in
      [Yy][Ee][Ss]|[Yy])
        return 0
        ;;
      [Nn][Oo]|[Nn])
        return 1
        ;;
      *) #Everything else is invalid
        ;;
    esac
  done
}

function download_cluster_credentials() {
  _tenant_id=$(yq eval '.provider.tenant_id' deploy.yml)
  _client_id=$(yq eval '.provider.client_id' deploy.yml)
  _client_secret=$(yq eval '.provider.client_secret' deploy.yml)
  az login --service-principal -u "${_client_id}" -p "${_client_secret}" -t "${_tenant_id}" &> /dev/null
  az aks get-credentials --name "$(name)" --resource-group "$(name)"
}

function cleanup_cluster_credentials() {
  _kubectl_user="clusterUser_$(name)_$(name)"
  _kubectl_cluster="$(name)"
  _kubectl_context="$(name)"
  if [[ "$(kubectl config current-context)" == "${_kubectl_context}" ]]; then
    kubectl config unset current-context
  fi
  kubectl config delete-user "${_kubectl_user}"
  kubectl config delete-cluster "${_kubectl_cluster}"
  kubectl config delete-context "${_kubectl_context}"
  if az account show &> /dev/null; then
    az logout
  fi
}

function terraform_init() {
  _tf_dir="${1}"
  "${HOME}/bin/terraform" -chdir="${_tf_dir}" init -reconfigure -backend-config=tf-backend.json > /dev/null
}

function terraform_plan() {
  _tf_dir="${1}"
  "${HOME}/bin/terraform" -chdir="${_tf_dir}" plan -out=tf-plan -var-file=tf-variables.json > /dev/null
  "${HOME}/bin/terraform" -chdir="${_tf_dir}" show tf-plan
}

function terraform_plan_destroy() {
  _tf_dir="${1}"
  if [[ "$("${HOME}/bin/terraform" -chdir="${_tf_dir}" state list | wc -l)" != "0" ]]; then
    "${HOME}/bin/terraform" -chdir="${_tf_dir}" plan -destroy -out=tf-plan -var-file=tf-variables.json > /dev/null
    "${HOME}/bin/terraform" -chdir="${_tf_dir}" show tf-plan
  else
    return 1
  fi
}

function terraform_apply() {
  _tf_dir="${1}"
  if [[ -f "${_tf_dir}/tf-plan" ]]; then
    "${HOME}/bin/terraform" -chdir="${_tf_dir}" apply tf-plan
  fi
}

function terraform_output() {
  _tf_dir="${1}"
  "${HOME}/bin/terraform" -chdir="${_tf_dir}" output
}

function handle_mode() {
  _mode="${1}"
  if [[ "${_mode}" == "install" ]]; then
    {
      echo ""
      echo "-----------------------------------------------------------------------"
      echo "Installing"
      echo "-----------------------------------------------------------------------"
      echo ""
      terraform_init "$(deploy_dir)"
      terraform_plan "$(deploy_dir)"
      terraform_apply "$(deploy_dir)"
      download_cluster_credentials
    }
  fi
  if [[ "${_mode}" == "uninstall" ]]; then
    {
      echo ""
      echo "-----------------------------------------------------------------------"
      echo "Uninstalling"
      echo "-----------------------------------------------------------------------"
      echo ""
      terraform_init "$(deploy_dir)"
      if terraform_plan_destroy "$(deploy_dir)"
      then
        if confirmation_prompt "Do you want to proceed to uninstall";
        then
          terraform_apply "$(deploy_dir)"
          cleanup_cluster_credentials
        else
          echo "Aborting current operation."
        fi
      else
        echo "No resources found to uninstall."
        cleanup_cluster_credentials
      fi
    }
  fi
}

function cleanup_deploy_dir() {
  rm -rf deploy
}

trap cleanup_deploy_dir EXIT

capture_mode "${@}"
log_operation "${1}"
install_local_tools
prepare_deploy_dir
handle_mode "${1}"
cleanup_deploy_dir
