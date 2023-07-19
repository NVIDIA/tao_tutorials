#! /bin/bash

success_code=0
set -e

function info() {
    echo -e "\033[1;32mINFO:\033[0m $1"
}

function error() {
    echo -e "\033[1;31mERROR:\033[0m $1"
}

function warning() {
    echo -e "\033[1;33mWARNING:\033[0m $1"
}

function print_usage() {
    echo "Quick start tool for TAO Toolkit launcher.
        
usage: bash quickstart_launcher.sh [--install] [--upgrade] [--help]

optional arguments:

--install       Install NVIDIA TAO Toolkit
--upgrade       Upgrade installed NVIDIA TAO Toolkit CLI
--help          Print this help message.
"
}

# Parse shell script CLI.
INSTALL="0"
UPGRADE="0"
PRINT_HELP="0"
# Parse command line.
while [[ $# -gt 0 ]]
    do
    key="$1"

    case $key in
        -i|--install)
        INSTALL="1"
        shift # past argument
        ;;
        -u|--upgrade)
        UPGRADE="1"
        INSTALL="1"
        shift # past argument
        ;;
        --help)
        PRINT_HELP="1"
        shift # past argument
        ;;
        --default)
        INSTALL="0"
        UPGRADE="0"
        PRINT_HELP="1"
        shift # past argument
        ;;
        -*|--*)
        echo "Unknown argument \"$key\""
        echo "Printing usage ..."
        print_usage
        exit 1
        ;;
        *)    # unknown option
        POSITIONAL+=("$1") # save it in an array for later
        shift # past argument
        ;;
    esac
done


# Check requirements before installing TAO toolkit.
function check_tao_requirements() {

    warnings=()
    info "Check requirements"

    info "Checking Python installation"
    # Check python.
    if ! command -v python3 >/dev/null; then
        error "python3 not found"
        return 1
    else
        info "python3 found."
        info "Python version: $(python --version)"
    fi

    # Check pip.
    if ! command -v pip3 >/dev/null; then
        error "pip3 not found"
        return 1
    else
        info "pip3 found."
        info "Pip version: $(pip --version)"
    fi

    docker_registry="nvcr.io"
    # Check docker.
    if ! command -v docker >/dev/null; then
        error "docker not found. Plaese install docker-ce"
        return 1
    else
        info "Docker found. Checking additional requirements for docker."
        if ! id -nG | grep -qw "docker"; then
            [[ $OSTYPE = darwin* ]] || error "You should add yourself to the docker group by running \"sudo usermod -a -G docker $(whoami)\"" && return 1
        fi
        if ! grep -q "nvcr.io" $HOME/.docker/config.json; then
            error "You should login to NGC container registry by running 'docker login -u \"\$oauthtoken\" ${docker_registry}'"
            return 1
        fi
    fi

    info "Checking nvidia-docker2 installation"
    if command -v nvidia-docker >/dev/null; then
        nvidia_docker_version=$(nvidia-docker version | grep "NVIDIA Docker:" | cut -d " " -f 3)
        [[ $nvidia_docker_version = 2* ]] || warning "nvidia-docker2 is required, current version is $nvidia_docker_version"
    else
        error "nvidia-docker not found."
    fi

    for w in "${warnings[@]}"; do
        echo -e "\033[1;33mWARNING:\033[0m $w"
    done

    check_for_and_download_ngc_cli

    # Successfully checked all dependencies.
    return 0
}

# Print EULA prompt.
function prompt_tao_toolkit_eula() {
    tao_toolkit_license_text="
    By installing the TAO Toolkit CLI, you accept the terms and conditions of this license:
    https://developer.nvidia.com/tao-toolkit-software-license-agreement"
    echo $tao_toolkit_license_text
    read -p  "Would you like to continue? (y/n): " confirm
    if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
        info "EULA accepted."
        return 0
    else
        return 1
    fi
}

# Simple function to install tao toolkit.
function install_tao_toolkit() {
    upgrade=$1
    if ! command -v jupyter >/dev/null; then
       info "Jupyter wasn't found."
       info " Installing Jupyter"
       pip3 install jupyter
       info "Installed jupyter"
       jupyter --version | grep jupyter_core
    else
        info "jupyter installation was found."
        jupyter --version
    fi

    if ! command -v tao >/dev/null; then
        info "TAO Toolkit was not installed."
        info "Installing TAO Toolkit."
        pip3 install nvidia-tao
        tao_version=(python -c "import tlt; tlt.__version__")
        info "Installed TAO wheel version: ${tao_version}"
    else
        info "TAO Toolkit was found"
    fi
    if [ $upgrade = "1" ]; then
        info "Upgrading installed nvidia-tao to the latest version."
        pip3 install nvidia-tao --upgrade
    fi
    info "$(tao info --verbose)"
}

# Download NGC CLI
function check_for_and_download_ngc_cli() {
    if ! command -v wget > /dev/null; then
        error "wget command not found. Please install wget"
        return 1
    fi
    if ! command -v ngc > /dev/null; then
        ngc_cli_url="https://ngc.nvidia.com/downloads/ngccli_linux.zip"
        wget --content-disposition $ngc_cli_url && unzip ngccli_linux.zip && chmod u+x ngc-cli/ngc
        echo "export PATH=\"$(pwd)/ngc-cli:\$PATH\"" >> ~/.bashrc
        source ~/.bashrc
        rm -rf $(pwd)/ngccli_linux.zip
        rm -rf $(pwd)/ngc-cli.md5
    else
        info "NGC CLI found."
    fi
    info "$(ngc --version)"
}


# Main function to run quick start.
function main() {
    if [ $PRINT_HELP = "1" ]; then
        print_usage
        return 0
    fi

    if [ $INSTALL = "1" ]; then
        check_tao_requirements
        requirements_status=$?

        if [[ $requirement_status -eq $success_code ]]; then
            info "Requirements check satisfied. Installing TAO Toolkit."
        fi
        prompt_tao_toolkit_eula
        info "Installing TAO Toolkit CLI"
        install_tao_toolkit $UPGRADE  
    fi
}

main
