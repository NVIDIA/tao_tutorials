#!/usr/bin/env bash
set -x
DESIRED_GPU_VERSION="${nvidia_driver_version}"
if [[ -z "$DESIRED_GPU_VERSION" ]]; then
  if ! hash helm 2> /dev/null; then
    if ! hash curl 2> /dev/null; then
      apt-get update
      apt-get -y install curl
    fi
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  fi
  helm repo add gpu-operator https://helm.ngc.nvidia.com/nvidia
  helm repo update
  DESIRED_GPU_VERSION="$(helm show values gpu-operator/gpu-operator --version '${gpu_operator_version}' --jsonpath '{.driver.version}')"
fi
GPU_FILEPATH=/usr/local/nvidia
KERNEL_VERSION=$(uname -r)
# Check current driver version
if [ -f "$GPU_FILEPATH/bin/nvidia-smi" ]; then
  NVIDIA_SMI_VERSION=$(nvidia-smi | grep "Driver Version" | cut -d' ' -f3)
  echo "NVIDIA-SMI version is $NVIDIA_SMI_VERSION"
  # If nvidia-smi does not match desired version, proceed
  if [ $NVIDIA_SMI_VERSION != $DESIRED_GPU_VERSION ]; then
    # Check NVIDIA Modprobe status
    systemctl is-active nvidia-device-plugin
    # Stop NVIDIA Modprobe
    systemctl stop nvidia-modprobe
    # Check NVIDIA Device plugin
    systemctl status nvidia-device-plugin
    # Uninstall NVIDIA Driver
    nvidia-uninstall --silent
    # Throw a trap so kubelet comes back up after
    trap 'systemctl restart kubelet' EXIT SIGINT SIGTERM
    if [ ! -d "$GPU_FILEPATH" ]; then
      mkdir -p $GPU_FILEPATH
    fi
    # Fetch Driver run file
    echo "Fetch NVIDIA Driver Run File"
    curl -fLS https://us.download.nvidia.com/tesla/$DESIRED_GPU_VERSION/NVIDIA-Linux-x86_64-$DESIRED_GPU_VERSION.run -o $GPU_FILEPATH/nvidia-drivers-$DESIRED_GPU_VERSION
    echo "Upgrading installer"
    systemctl stop kubelet
    sh $GPU_FILEPATH/nvidia-drivers-$DESIRED_GPU_VERSION -s -k=$KERNEL_VERSION -a --no-drm --dkms --utility-prefix="$GPU_FILEPATH" --opengl-prefix="$GPU_FILEPATH" 2>&1
    nvidia-modprobe -u -c0
    ldconfig
    systemctl start kubelet
    echo "Finished upgrading NVIDIA GPU Driver on Host to $DESIRED_GPU_VERSION"
    # Validate
    $GPU_FILEPATH/bin/nvidia-smi
  else
    echo "Current NVIDIA Driver version matches installed version."
  fi
fi