#!/bin/bash

set -Ee

function capture_mode() {
  if [[ -z "${1}" ]]; then
    echo -e "Usage: \n bash setup.sh [OPTIONS]\n \n Available Options: \n      check-inventory   Check provided inventory\n      install           Install TAO Toolkit API\n      uninstall         Uninstall TAO Toolkit API\n      validate          Validate TAO Toolkit API Installation"
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
  if [[ ${os} != "ubuntu" || ${os_version} != "22.04" ]]; then
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

function install_python_3() {
  if ! hash python3 2>/dev/null || ! python3 -m pip list &> /dev/null; then
    local os
    os=$(get_os)
    local os_version
    os_version=$(get_os_version)
    if [[ ${os} == "ubuntu" ]]; then
      echo "Installing / Updating python3 and pip"
      {
        sudo apt-get update
        sudo apt-get install python3 python3-dev python3-distutils python3-venv python3-pip -y
      } > /dev/null
    fi
  fi
}

function exit_venv() {
  deactivate 2> /dev/null || true
}

function setup_ansible() {
  exit_venv
  install_python_3
  PATH="${HOME}/.local/bin:${PATH}"
  {
    python3 -m pip install pip
    python3 -m pip install virtualenv
    rm -rf ansible-venv
    virtualenv --always-copy ansible-venv
    source ansible-venv/bin/activate
  } > /dev/null
  trap exit_venv EXIT
  {
    pip install --upgrade pip
    pip install ansible
    pip install -r requirements.txt
  } > /dev/null
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
      curl --silent -L https://github.com/mikefarah/yq/releases/download/v4.34.1/yq_linux_amd64 -o /tmp/yq
      sudo install -o root -g root -m 0755 /tmp/yq /usr/local/bin/yq
    } > /dev/null
  elif ! dpkg --compare-versions "$(yq --version | grep 'mikefarah' | awk '{print $4}' | tr -d 'v' 2> /dev/null || echo "")" ge '4.34.1'; then
    echo "Installing yq"
    {
      sudo rm -f "$(which yq)"
      rm -f /tmp/yq
      curl --silent -L https://github.com/mikefarah/yq/releases/download/v4.34.1/yq_linux_amd64 -o /tmp/yq
      sudo install -o root -g root -m 0755 /tmp/yq /usr/local/bin/yq
    } > /dev/null
  fi
}

function install_local_tools() {
  check_os_and_version_supported
  check_user_has_password_less_sudo
  check_internet_access
  setup_ansible
  jq_install
  yq_install
}

function prepare_inventory() {
  touch hosts
}

function check_inventory() {
  ansible-playbook -i hosts --flush-cache check-inventory.yml --extra-vars "mode=${1}"
}

function capture_gpu_driver_override() {
  ansible-playbook -i hosts --flush-cache capture-gpu-driver-override.yml
}

function clear_old_gpu_operator_artifacts() {
  ansible-playbook -i hosts --flush-cache clear-old-gpu-operator-artifacts.yml
}

function prepare_cns() {
  yq eval '.spec.cns' deploy.yml > /tmp/cns.yml
  yq eval-all '. as $item ireduce ({}; . * $item )' cns/cns_default_values.yaml /tmp/cns.yml > cns/cns_values.yaml
  sed -i "s|https_proxy:.*|https_proxy: \"$HTTPS_PROXY\"|g" cns/cns_values.yaml
  sed -i "s|http_proxy:.*|http_proxy: \"$HTTP_PROXY\"|g" cns/cns_values.yaml
  sed -i "s|^proxy:.*|proxy: $(if [ -z """$HTTPS_PROXY$HTTP_PROXY""" ]; then echo no; else echo yes; fi)|g" cns/cns_values.yaml
  if [ -f my-cert.crt ]; then
    echo -e "\n# Self-Signed CA Certificate\nmy_cert: yes" >> cns/cns_values.yaml
  fi
}

function prepare_tao() {
  yq eval '.spec.tao' deploy.yml > tao-toolkit-api-ansible-values.yml
  yq eval '.name' deploy.yml -o json | jq '{cluster_name: .}' | yq -P >> tao-toolkit-api-ansible-values.yml
  if [ ! -z $HTTPS_PROXY ]; then
    sed -i "/^https_proxy:/d" tao-toolkit-api-ansible-values.yml
    echo -e "\nhttps_proxy: $HTTPS_PROXY" >> tao-toolkit-api-ansible-values.yml
  fi
  if [ -f my-cert.crt ]; then
    sed -i "/^my_cert:/d" tao-toolkit-api-ansible-values.yml
    echo -e "\nmy_cert: yes" >> tao-toolkit-api-ansible-values.yml
  fi
}

function uninstall_existing_nvidia_drivers() {
  ansible-playbook -i hosts --flush-cache uninstall-nvidia-drivers.yml
}

function check_nouveau_not_present() {
  ansible-playbook -i hosts --flush-cache check-nouveau-not-present.yml
}

function uninstall_existing_cluster() {
  ansible-playbook -i hosts --flush-cache cns/cns-uninstall.yaml
}

function install_new_cluster() {
  ansible-playbook -i hosts --flush-cache cns/cns-installation.yaml
}

function validate_cluster() {
  ansible-playbook -i hosts --flush-cache cns/cns-validation.yaml
}

function install_tao_toolkit_api() {
  ansible-playbook -i hosts --flush-cache install-tao-toolkit-api.yml
}

capture_mode "${@}"
install_local_tools
prepare_inventory
if [[ "${1}" == "check-inventory" ]]; then
  check_inventory "${1}"
fi
if [[ "${1}" == "install" ]]; then
  check_inventory "${1}"
  clear_old_gpu_operator_artifacts
  prepare_cns
  uninstall_existing_nvidia_drivers
  uninstall_existing_cluster
  install_new_cluster
  validate_cluster
  check_nouveau_not_present
  prepare_tao
  install_tao_toolkit_api
fi
if [[ "${1}" == "uninstall" ]]; then
  check_inventory "${1}"
  prepare_cns
  uninstall_existing_nvidia_drivers
  uninstall_existing_cluster
fi
if [[ "${1}" == "validate" ]]; then
  capture_gpu_operator_values
  check_inventory "${1}"
  prepare_cns
  validate_cluster
fi
