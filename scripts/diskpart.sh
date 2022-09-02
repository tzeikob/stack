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

  echo "Disk partitioning has been completed"
}

format_them () {
  echo "Start formating disk partitions..."

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
  echo "Mounting disk partitions..."

  local ROOT_INDEX=2

  if [ "$IS_UEFI" = "yes" ]; then
    if [ "$SWAP" = "yes" ] && [ "$SWAP_TYPE" = "partition" ]; then
      swapon ${DISK}2
      echo "Swap partition set to on"

      ROOT_INDEX=3
    fi

    mount ${DISK}${ROOT_INDEX} /mnt
    echo "Root partition mounted"

    mount --mkdir ${DISK}1 /mnt/boot
    echo "Boot partition mounted"
  else
    ROOT_INDEX=1

    if [ "$SWAP" = "yes" ] && [ "$SWAP_TYPE" = "partition" ]; then
      swapon ${DISK}1
      echo "Swap partition set to on"

      ROOT_INDEX=2
    fi

    mount ${DISK}${ROOT_INDEX} /mnt
    echo "Root partition mounted"
  fi

  echo "Mounting has been completed"
}

report () {
  echo -e "Disk layout is now set to:\n"

  parted --script $DISK print | awk '{print " "$0}'

  lsblk $DISK -o NAME,SIZE,TYPE,MOUNTPOINTS | awk '{print " "$0}'
}

echo -e "\nStarting disk partitioning..."

source $OPTIONS

create_partitions &&
  format_them &&
  mount_them &&
  report

echo -e "\nDisk partitioning has been completed"
echo "Moving to the next process..."
sleep 5
