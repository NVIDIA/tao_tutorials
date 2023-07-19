#!/bin/bash

set -euo pipefail

DEBIAN_FRONTEND="noninteractive"

chroot "${ROOT_MOUNT_DIR}" apt-get -y update
chroot "${ROOT_MOUNT_DIR}" apt-get -y install nfs-common