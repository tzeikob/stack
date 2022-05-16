#!/usr/bin/env bash

VERSION="0.1.0"

BLANK="^(""|[ *])$"
YES="^([Yy][Ee][Ss]|[Yy])$"

abort () {
  echo -e "\n$1"
  echo -e "Process exiting with code: $2"

  exit $2
}

echo -e "Stack v$VERSION"
echo -e "Starting base installation process"

if [ ! -d "/sys/firmware/efi/efivars" ]; then
  abort "This script supports only UEFI systems" 1
fi

echo -e "\nPartitioning and formatting the installation disk..."
echo -e "The following disks found in your system:"

lsblk

read -p "Enter the device path of the disk to apply the installation: " device

while [ ! -b "$device" ]; do
  echo -e "Invalid device path: '$device'"
  read -p "Please enter a valid device path: " device
done