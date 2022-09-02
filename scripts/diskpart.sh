#!/usr/bin/env bash

create_partitions () {
  if [ "$IS_UEFI" = "yes" ]; then
    echo "Creating a clean GPT partition table..."

    parted --script $DISK mklabel gpt

    local FROM=1
    local TO=501

    parted --script $DISK mkpart "Boot" fat32 ${FROM}MiB ${TO}MiB
    parted --script $DISK set 1 boot on

    echo "Boot partition has been created"

    FROM=$TO

    if [ "$SWAP" = "yes" ] && [ "$SWAP_TYPE" = "partition" ]; then
      TO=$((FROM + (SWAP_SIZE * 1024)))

      parted --script $DISK mkpart "Swap" linux-swap ${FROM}Mib ${TO}Mib

      echo "Swap partition has been created"

      FROM=$TO
    fi

    parted --script $DISK mkpart "Root" ext4 ${FROM}Mib 100%

    echo "Root partition has been created"
  else
    echo "Creating a clean MBR partition table..."

    parted --script $DISK mklabel msdos

    local FROM=1
    local BOOT_INDEX=1

    if [ "$SWAP" = "yes" ] && [ "$SWAP_TYPE" = "partition" ]; then
      local TO=$((FROM + (SWAP_SIZE * 1024)))

      parted --script $DISK mkpart primary linux-swap ${FROM}Mib ${TO}Mib

      echo "Swap partition has been created"

      FROM=$TO
      BOOT_INDEX=2
    fi

    parted --script $DISK mkpart primary ext4 ${FROM}Mib 100%
    parted --script $DISK set $BOOT_INDEX boot on

    echo "Root partition has been created"
  fi

  echo -e "\nPartitioning table is set to:"

  parted --script $DISK print | awk '{print " "$0}'

  echo "Disk partitioning has been completed"
}

format_them () {
  echo -e "\nStart formating partitions..."

  local ROOT_INDEX=2

  if [ "$IS_UEFI" = "yes" ]; then
    mkfs.fat -F 32 ${DISK}1

    if [ "$SWAP" = "yes" ] && [ "$SWAP_TYPE" = "partition" ]; then
      mkswap ${DISK}2
      ROOT_INDEX=3
    fi

    mkfs.ext4 -F ${DISK}${ROOT_INDEX}
  else
    ROOT_INDEX=1

    if [ "$SWAP" = "yes" ] && [ "$SWAP_TYPE" = "partition" ]; then
      mkswap ${DISK}1
      ROOT_INDEX=2
    fi

    mkfs.ext4 -F ${DISK}${ROOT_INDEX}
  fi

  echo "Formating has been completed"
}

mount_them () {
  echo -e "\nMounting disk partitions..."

  local ROOT_INDEX=2

  if [ "$IS_UEFI" = "yes" ]; then
    if [ "$SWAP" = "yes" ] && [ "$SWAP_TYPE" = "partition" ]; then
      swapon ${DISK}2
      ROOT_INDEX=3
    fi

    mount ${DISK}${ROOT_INDEX} /mnt
    mount --mkdir ${DISK}1 /mnt/boot
  else
    ROOT_INDEX=1

    if [ "$SWAP" = "yes" ] && [ "$SWAP_TYPE" = "partition" ]; then
      swapon ${DISK}1
      ROOT_INDEX=2
    fi

    mount ${DISK}${ROOT_INDEX} /mnt
  fi

  echo "Mounting has been completed"
}

report () {
  echo -e "\nDisk layout is now set to:"

  lsblk $DISK -o NAME,SIZE,TYPE,MOUNTPOINTS | awk '{print " "$0}'
}

echo -e "\nStarting disk partitioning..."

source $OPTIONS

create_partitions && read A &&
  format_them && read A &&
  mount_them && read A &&
  report read A &&

echo -e "\nDisk partitioning has been completed"
echo "Moving to the next process..."
sleep 5
