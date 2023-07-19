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

function install_python_3_8() {
  if ! hash python3.8 2>/dev/null || ! python3.8 -m pip list &> /dev/null; then
    local os
    os=$(get_os)
    local os_version
    os_version=$(get_os_version)
    if [[ ${os} == "ubuntu" ]]; then
      echo "Installing / Updating python3.8 and pip"
      {
        sudo apt-get update
        sudo apt-get install python3.8 python3.8-dev python3.8-distutils python3.8-venv python3-pip -y
      } > /dev/null
    fi
  fi
}

function exit_venv() {
  deactivate 2> /dev/null || true
}

function setup_ansible() {
  exit_venv
  install_python_3_8
  PATH="${HOME}/.local/bin:${PATH}"
  {
    python3.8 -m pip install pip
    python3.8 -m pip install virtualenv
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

function install_local_tools() {
  check_os_and_version_supported
  check_user_has_password_less_sudo
  check_internet_access
  setup_ansible
}

function capture_inventory() {
  local hosts_file_path
  local default_hosts_file_path
  default_hosts_file_path="./hosts"
  read -r -p "Provide the path to the hosts file [${default_hosts_file_path}]: " hosts_file_path
  if [[ -n "${hosts_file_path}" && "${default_hosts_file_path}" != "${hosts_file_path}" ]]; then
    cp "${hosts_file_path}" "${default_hosts_file_path}"
  fi
}

function capture_gpu_operator_values() {
  touch gpu-operator-values.yml
  local enable_mig
  local existing_enable_mig
  existing_enable_mig=$(grep '^enable_mig' gpu-operator-values.yml | awk '{print $2}')
  if [[ -n "${existing_enable_mig}" ]]; then
    read -r -p "Provide the value for enable_mig (no/yes) [${existing_enable_mig}]: " enable_mig
    enable_mig="${enable_mig:=${existing_enable_mig}}"
  else
    read -r -p "Provide the value for enable_mig (no/yes): " enable_mig
    if [[ -z "${enable_mig}" ]]; then
      echo "Script requires enable_mig value to proceed"
      exit 1
    fi
  fi
  local mig_profile
  local existing_mig_profile
  existing_mig_profile=$(grep '^mig_profile' gpu-operator-values.yml | awk '{print $2}')
  if [[ -n "${existing_mig_profile}" ]]; then
    read -r -p "Provide the value for mig_profile [${existing_mig_profile}]: " mig_profile
    mig_profile="${mig_profile:=${existing_mig_profile}}"
  else
    read -r -p "Provide the value for mig_profile: " mig_profile
    if [[ -z "${mig_profile}" ]]; then
      echo "Script requires mig_profile value to proceed"
      exit 1
    fi
  fi
  local mig_strategy
  local existing_mig_strategy
  existing_mig_strategy=$(grep '^mig_strategy' gpu-operator-values.yml | awk '{print $2}')
  if [[ -n "${existing_mig_strategy}" ]]; then
    read -r -p "Provide the value for mig_strategy (single/mixed) [${existing_mig_strategy}]: " mig_strategy
    mig_strategy="${mig_strategy:=${existing_mig_strategy}}"
  else
    read -r -p "Provide the value for mig_strategy (single/mixed): " mig_strategy
    if [[ -z "${mig_strategy}" ]]; then
      echo "Script requires mig_strategy value to proceed"
      exit 1
    fi
  fi
  local nvidia_driver_version
  local existing_nvidia_driver_version
  existing_nvidia_driver_version=$(grep '^nvidia_driver_version' gpu-operator-values.yml | awk '{print $2}' | tr -d '"')
  if [[ -n "${existing_nvidia_driver_version}" ]]; then
    read -r -p "Provide the value for nvidia_driver_version [${existing_nvidia_driver_version}]: " nvidia_driver_version
    nvidia_driver_version="${nvidia_driver_version:=${existing_nvidia_driver_version}}"
    nvidia_driver_version="$(echo "${nvidia_driver_version}" | tr -d '"' | tr -d "'")"
  else
    read -r -p "Provide the value for nvidia_driver_version: " nvidia_driver_version
    if [[ -z "${nvidia_driver_version}" ]]; then
      echo "Script requires nvidia_driver_version value to proceed"
      exit 1
    fi
  fi
  sed -i "s|enable_mig:.*|enable_mig: ${enable_mig}|g" ./gpu-operator-values.yml
  sed -i "s|mig_profile:.*|mig_profile: ${mig_profile}|g" ./gpu-operator-values.yml
  sed -i "s|mig_strategy:.*|mig_strategy: ${mig_strategy}|g" ./gpu-operator-values.yml
  sed -i "s|nvidia_driver_version:.*|nvidia_driver_version: \"${nvidia_driver_version}\"|g" ./gpu-operator-values.yml
}

function capture_ngc_config() {
  touch tao-toolkit-api-ansible-values.yml
  local ngc_api_key
  local existing_ngc_api_key
  existing_ngc_api_key=$(grep '^ngc_api_key' tao-toolkit-api-ansible-values.yml | awk '{print $2}')
  if [[ -n "${existing_ngc_api_key}" ]]; then
    read -r -p "Provide the ngc-api-key [${existing_ngc_api_key}]: " ngc_api_key
    ngc_api_key="${ngc_api_key:=${existing_ngc_api_key}}"
  else
    read -r -p "Provide the ngc-api-key: " ngc_api_key
    if [[ -z "${ngc_api_key}" ]]; then
      echo "Script requires ngc-api-key to proceed"
      exit 1
    fi
  fi
  local ngc_email
  local existing_ngc_email
  existing_ngc_email=$(grep '^ngc_email' tao-toolkit-api-ansible-values.yml | awk '{print $2}')
  if [[ -n "${existing_ngc_email}" ]]; then
    read -r -p "Provide the ngc-email [${existing_ngc_email}]: " ngc_email
    ngc_email="${ngc_email:=${existing_ngc_email}}"
  else
    read -r -p "Provide the ngc-email: " ngc_email
    if [[ -z "${ngc_email}" ]]; then
      echo "Script requires ngc-email to proceed"
      exit 1
    fi
  fi
  local api_chart
  local existing_api_chart
  existing_api_chart=$(grep '^api_chart' tao-toolkit-api-ansible-values.yml | awk '{print $2}')
  if [[ -n "${existing_api_chart}" ]]; then
    read -r -p "Provide the api-chart [${existing_api_chart}]: " api_chart
    api_chart="${api_chart:=${existing_api_chart}}"
  else
    read -r -p "Provide the api-chart: " ngc_email
    if [[ -z "${api_chart}" ]]; then
      echo "Script requires api-chart to proceed"
      exit 1
    fi
  fi
  local api_values
  local existing_api_values
  existing_api_values="$(grep '^api_values' tao-toolkit-api-ansible-values.yml | awk '{print $2}')"
  if [[ -n "${existing_api_values}" ]]; then
    read -r -p "Provide the api-values [${existing_api_values}]: " api_values
    api_values="${api_values:=${existing_api_values}}"
  else
    read -r -p "Provide the api-values: " api_values
    if [[ -z "${api_values}" ]]; then
      echo "Script requires api-values to proceed"
      exit 1
    fi
  fi
  sed -e '/^ngc_api_key:.*/d' -e '/^ngc_email:.*/d' -e '/^api_chart:.*/d' -e '/^api_values:.*/d' -i tao-toolkit-api-ansible-values.yml
  local cluster_name
  local existing_cluster_name
  existing_cluster_name="$(grep '^cluster_name' tao-toolkit-api-ansible-values.yml | awk '{print $2}')"
  if [[ -n "${existing_cluster_name}" ]]; then
    read -r -p "Provide the cluster-name [${existing_cluster_name}]: " cluster_name
    cluster_name="${cluster_name:=${existing_cluster_name}}"
  else
    read -r -p "Provide the cluster-name: " cluster_name
    if [[ -z "${cluster_name}" ]]; then
      echo "Script requires cluster-name to proceed"
      exit 1
    fi
  fi
  sed -e '/^ngc_api_key:.*/d' -e '/^ngc_email:.*/d' -e '/^api_chart:.*/d' -e '/^api_values:.*/d' -e '/^cluster_name:.*/d' -i tao-toolkit-api-ansible-values.yml
  echo "ngc_api_key: ${ngc_api_key}" | tee -a tao-toolkit-api-ansible-values.yml 1> /dev/null
  echo "ngc_email: ${ngc_email}" | tee -a tao-toolkit-api-ansible-values.yml 1> /dev/null
  echo "api_chart: ${api_chart}" | tee -a tao-toolkit-api-ansible-values.yml 1> /dev/null
  echo "api_values: ${api_values}" | tee -a tao-toolkit-api-ansible-values.yml 1> /dev/null
  echo "cluster_name: ${cluster_name}" | tee -a tao-toolkit-api-ansible-values.yml 1> /dev/null
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

function prepare_cnc() {
  local os
  os=$(get_target_os)
  local os_version
  os_version=$(get_target_os_version)
  if [[ ${os} == "Ubuntu" && ${os_version} == "20.04"  ]]; then
    cp cnc/cnc_values_6.1.yaml cnc/cnc_values.yaml
  elif [[ ${os} == "Ubuntu" && ${os_version} == "18.04"  ]]; then
    cp cnc/cnc_values_3.1.yaml cnc/cnc_values.yaml
  else
    echo "Cluster cannot be configured on hosts running ${os} : ${os_version}"
    exit 1
  fi
  sed -i "s|enable_mig:.*|$(grep '^enable_mig:' ./gpu-operator-values.yml)|g" cnc/cnc_values.yaml
  sed -i "s|mig_profile:.*|$(grep '^mig_profile:' ./gpu-operator-values.yml)|g" cnc/cnc_values.yaml
  sed -i "s|mig_strategy:.*|$(grep '^mig_strategy:' ./gpu-operator-values.yml)|g" cnc/cnc_values.yaml
  sed -i "s|gpu_driver_version:.*|$(grep '^nvidia_driver_version:' ./gpu-operator-values.yml)|g" cnc/cnc_values.yaml
  sed -i 's|nvidia_driver_version|gpu_driver_version|g' cnc/cnc_values.yaml
  sed -i "s|install_driver:.*|$(grep '^install_driver:' ./gpu-operator-values.yml)|g" cnc/cnc_values.yaml
  sed -i "s|https_proxy:.*|https_proxy: \"$HTTPS_PROXY\"|g" cnc/cnc_values.yaml
  sed -i "s|http_proxy:.*|http_proxy: \"$HTTP_PROXY\"|g" cnc/cnc_values.yaml
  sed -i "s|^proxy:.*|proxy: $(if [ -z """$HTTPS_PROXY$HTTP_PROXY""" ]; then echo no; else echo yes; fi)|g" cnc/cnc_values.yaml
  if [ -f my-cert.crt ]; then
    echo -e "\n# Self-Signed CA Certificate\nmy_cert: yes" >> cnc/cnc_values.yaml
  fi
}

function prepare_tao() {
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
  ansible-playbook -i hosts --flush-cache cnc/cnc-uninstall.yaml
}

function install_new_cluster() {
  ansible-playbook -i hosts --flush-cache cnc/cnc-installation.yaml
}

function validate_cluster() {
  ansible-playbook -i hosts --flush-cache cnc/cnc-validation.yaml
}

function install_tao_toolkit_api() {
  ansible-playbook -i hosts --flush-cache install-tao-toolkit-api.yml
}

capture_mode "${@}"
install_local_tools
capture_inventory
if [[ "${1}" == "check-inventory" ]]; then
  check_inventory "${1}"
fi
if [[ "${1}" == "install" ]]; then
  capture_ngc_config
  capture_gpu_operator_values
  check_inventory "${1}"
  capture_gpu_driver_override
  clear_old_gpu_operator_artifacts
  prepare_cnc
  uninstall_existing_nvidia_drivers
  uninstall_existing_cluster
  install_new_cluster
  validate_cluster
  check_nouveau_not_present
  prepare_tao
  install_tao_toolkit_api
fi
if [[ "${1}" == "uninstall" ]]; then
  capture_gpu_operator_values
  check_inventory "${1}"
  capture_gpu_driver_override
  prepare_cnc
  uninstall_existing_nvidia_drivers
  uninstall_existing_cluster
fi
if [[ "${1}" == "validate" ]]; then
  capture_gpu_operator_values
  check_inventory "${1}"
  prepare_cnc
  validate_cluster
fi
