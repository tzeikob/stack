#!/usr/bin/env bash

shopt -s nocasematch

source .options

echo -e "\nPartitioning the installation disk..."
echo "Installation disk set to block device $DISK"

echo -e "\nIMPORTANT, all data in $DISK will be lost"
read -p "Do you want to proceed and partition the disk? [y/N] " REPLY
REPLY=${REPLY:-"no"}

if [[ ! $REPLY =~ ^(yes|y)$ ]]; then
  echo -e "\nCanceling the disk partitioning process..."
  echo "Process exiting with code: 1"
  exit 1
fi

if [[ $IS_UEFI == true ]]; then
  echo -e "\nCreating a clean GPT partition table..."

  parted --script $DISK mklabel gpt

  parted --script $DISK mkpart "Boot" fat32 1MiB 501MiB
  parted --script $DISK set 1 boot on

  echo "Boot partition created under ${DISK}1"

  parted --script $DISK mkpart "Root" ext4 501Mib 100%

  echo "Root partition created under ${DISK}2"

  echo -e "Partitioning table completed successfully:\n"

  parted --script $DISK print

  echo "Formatting partitions in $DISK..."

  mkfs.fat -F 32 ${DISK}1
  mkfs.ext4 -F -q ${DISK}2

  echo "Formating has been completed successfully"

  echo -e "\nMounting the boot and root partitions..."

  mount ${DISK}2 /mnt
  mount --mkdir ${DISK}1 /mnt/boot

  echo "Boot partition ${DISK}1 mounted to /mnt/boot"
  echo "Root partition ${DISK}2 mounted to /mnt"
else
  echo -e "\nCreating a clean MBR partition table..."

  parted --script $DISK mklabel msdos

  parted --script $DISK mkpart primary ext4 1Mib 100%
  parted --script $DISK set 1 boot on

  echo "Root partition created under ${DISK}1"

  echo -e "Partitioning table completed successfully:\n"

  parted --script $DISK print

  echo -e "\nFormatting partitions in $DISK..."

  mkfs.ext4 -F -q ${DISK}1

  echo "Formating has been completed successfully"

  echo -e "\nMounting the root partition..."

  mount ${DISK}1 /mnt

  echo "Root partition ${DISK}1 mounted to /mnt"
fi

echo "Disk layout of $DISK after partitioning:\n"

lsblk $DISK

echo "Disk partitioning has been completed successfully"
