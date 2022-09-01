#!/usr/bin/env bash

create_gpt () {
  echo "Creating a clean GPT partition table..."

  parted --script $DISK mklabel gpt

  local FROM=1
  local TO=501

  parted --script $DISK mkpart "Boot" fat32 ${FROM}MiB ${TO}MiB
  parted --script $DISK set 1 boot on

  echo "Boot partition created successfully"

  FROM=$TO

  if [ "$SWAP" = "yes" ] && [ "$SWAP_TYPE" = "partition" ]; then
    TO=$((FROM + (SWAP_SIZE * 1024)))

    parted --script $DISK mkpart "Swap" linux-swap ${FROM}Mib ${TO}Mib

    echo "Swap partition created successfully"

    FROM=$TO
  fi

  parted --script $DISK mkpart "Root" ext4 ${FROM}Mib 100%

  echo "Root partition created successfully"

  echo -e "\nPartitioning table is set to:"

  parted --script $DISK print | awk '{print " "$0}'

  echo "Starting formating partitions..."

  mkfs.fat -F 32 ${DISK}1

  if [ "$SWAP" = "yes" ] && [ "$SWAP_TYPE" = "partition" ]; then
    mkswap ${DISK}2
    mkfs.ext4 -F -q ${DISK}3
  else
    mkfs.ext4 -F -q ${DISK}2
  fi

  echo "Formating has been completed successfully"

  echo -e "\nMounting the boot and root partitions..."

  if [ "$SWAP" = "yes" ] && [ "$SWAP_TYPE" = "partition" ]; then
    swapon ${DISK}2
    mount ${DISK}3 /mnt
  else
    mount ${DISK}2 /mnt
  fi

  mount --mkdir ${DISK}1 /mnt/boot

  echo "Partition have been mounted successfully"
}

create_mbr () {
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
}

echo -e "\nStarting disk partitioning..."

source $OPTIONS

if [ "$IS_UEFI" = "yes" ]; then
  create_gpt
else
  create_mbr
fi

echo -e "\nDisk layout is now set to:"

lsblk $DISK -o NAME,SIZE,TYPE,MOUNTPOINTS | awk '{print " "$0}'

echo -e "\nDisk partitioning has been completed"
echo "Moving to the next process..."
sleep 5
