#!/usr/bin/env bash

source $HOME/.options

echo "Starting disk partitioning for disk $DISK..."

if [[ $IS_UEFI == "yes" ]]; then
  echo "Creating a clean GPT partition table..."

  parted --script $DISK mklabel gpt

  parted --script $DISK mkpart "Boot" fat32 1MiB 501MiB
  parted --script $DISK set 1 boot on

  echo "Boot partition ${DISK}1 created successfully"

  parted --script $DISK mkpart "Root" ext4 501Mib 100%

  echo "Root partition ${DISK}2 created successfully"

  echo -e "\nPartitioning table is set to:"

  parted --script $DISK print | awk '{print " "$0}'

  echo "Formating partition filesystems..."

  mkfs.fat -F 32 ${DISK}1
  mkfs.ext4 -F -q ${DISK}2

  echo "Formating has been completed successfully"

  echo -e "\nMounting the boot and root partitions..."

  mount ${DISK}2 /mnt
  mount --mkdir ${DISK}1 /mnt/boot

  echo "Boot partition ${DISK}1 mounted to /mnt/boot"
  echo "Root partition ${DISK}2 mounted to /mnt"
else
  echo "Creating a clean MBR partition table..."

  parted --script $DISK mklabel msdos

  parted --script $DISK mkpart primary ext4 1Mib 100%
  parted --script $DISK set 1 boot on

  echo "Root partition ${DISK}1 created successfully"

  echo -e "\nPartitioning table is set to:"

  parted --script $DISK print | awk '{print " "$0}'

  echo "Formatting partition filesystem..."

  mkfs.ext4 -F -q ${DISK}1

  echo "Formating has been completed successfully"

  echo -e "\nMounting the root partition..."

  mount ${DISK}1 /mnt

  echo "Root partition ${DISK}1 mounted to /mnt"
fi

echo -e "\nDisk layout is set to:"

lsblk $DISK -o NAME,SIZE,TYPE,MOUNTPOINTS | awk '{print " "$0}'

echo -e "Partitioning done! Moving to the next process...\n"
sleep 5
