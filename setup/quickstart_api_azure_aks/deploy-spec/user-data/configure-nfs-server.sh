#!/bin/bash

apt-get -y update
apt-get -y install nfs-kernel-server
mkdir -p /csp_mnt/nfs_share
chown -R nobody:nogroup /csp_mnt/nfs_share
chmod 777 /csp_mnt/nfs_share
echo "/csp_mnt/nfs_share *(rw,sync,no_subtree_check)" | tee -a /etc/exports
exportfs -a
systemctl restart nfs-kernel-server