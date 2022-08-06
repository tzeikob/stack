#!/usr/bin/env bash

shopt -s nocasematch

source .options

echo -e "\nStarting the base installation..."

if [[ $KERNELS =~ ^stable$ ]]; then
  KERNELS="linux linux-headers"
elif [[ $KERNELS =~ ^lts$ ]]; then
  KERNELS="linux-lts linux-lts-headers"
else
  KERNELS="linux linux-lts linux-headers linux-lts-headers"
fi

pacstrap /mnt base $KERNELS linux-firmware archlinux-keyring reflector rsync sudo

echo "Base packages have been installed successfully"

echo -e "\nCreating the file system table..."

genfstab -U /mnt >> /mnt/etc/fstab

echo "The file system table has been created in '/mnt/etc/fstab'"

echo "Base installation has been completed successfully"
