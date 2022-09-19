#!/usr/bin/env bash

set -Eeo pipefail

unmount_all () {
  echo "Making sure everything is unmounted..."

  umount -A --recursive /mnt

  echo "Unmounting process has been completed"
}

create_partitions () {
  if [ "$IS_UEFI" = "yes" ]; then
    echo "Creating a clean GPT partition table..."

    parted --script "$DISK" mklabel gpt

    local FROM=1
    local TO=501

    parted --script "$DISK" mkpart "Boot" fat32 "${FROM}MiB" "${TO}MiB"
    parted --script "$DISK" set 1 boot on

    echo "Boot partition has been created"

    FROM=$TO

    if [ "$SWAP" = "yes" ] && [ "$SWAP_TYPE" = "partition" ]; then
      TO=$((FROM + (SWAP_SIZE * 1024)))

      parted --script "$DISK" mkpart "Swap" linux-swap "${FROM}Mib" "${TO}Mib"

      echo "Swap partition has been created"

      FROM=$TO
    fi

    parted --script "$DISK" mkpart "Root" ext4 "${FROM}Mib" 100%

    echo "Root partition has been created"
  else
    echo "Creating a clean MBR partition table..."

    parted --script "$DISK" mklabel msdos

    local FROM=1
    local ROOT_DEV_INDEX=1

    if [ "$SWAP" = "yes" ] && [ "$SWAP_TYPE" = "partition" ]; then
      local TO=$((FROM + (SWAP_SIZE * 1024)))

      parted --script "$DISK" mkpart primary linux-swap "${FROM}Mib" "${TO}Mib"

      echo "Swap partition has been created"

      FROM=$TO
      ROOT_DEV_INDEX=2
    fi

    parted --script "$DISK" mkpart primary ext4 "${FROM}Mib" 100%
    parted --script "$DISK" set "$ROOT_DEV_INDEX" boot on

    echo "Root partition has been created"
  fi

  echo "Disk partitioning has been completed"
}

format_partitions () {
  echo "Start formating partitions..."

  if [ "$IS_UEFI" = "yes" ]; then
    echo "Formating boot partition..."

    mkfs.fat -F 32 "${DISK}1"

    echo "Formating root partition..."

    if [ "$SWAP" = "yes" ] && [ "$SWAP_TYPE" = "partition" ]; then
      mkfs.ext4 -F "${DISK}3"
    else
      mkfs.ext4 -F "${DISK}2"
    fi
  else
    echo "Formating root partition..."

    if [ "$SWAP" = "yes" ] && [ "$SWAP_TYPE" = "partition" ]; then
      mkfs.ext4 -F "${DISK}2"
    else
      mkfs.ext4 -F "${DISK}1"
    fi
  fi

  echo "Formating has been completed"
}

mount_filesystem () {
  echo "Mounting disk partitions..."

  if [ "$IS_UEFI" = "yes" ]; then
    if [ "$SWAP" = "yes" ] && [ "$SWAP_TYPE" = "partition" ]; then
      mount "${DISK}3" /mnt
    else
      mount "${DISK}2" /mnt
    fi

    echo "Root partition mounted"

    mount --mkdir "${DISK}1" /mnt/boot

    echo "Boot partition mounted"
  else
    if [ "$SWAP" = "yes" ] && [ "$SWAP_TYPE" = "partition" ]; then
      mount "${DISK}2" /mnt
    else
      mount "${DISK}1" /mnt
    fi

    echo "Root partition mounted"
  fi

  echo "Mounting has been completed"
}

make_swap () {
  if [ "$SWAP" = "yes" ]; then
    echo "Setting up swap..."

    if [ "$SWAP_TYPE" = "partition" ]; then
      echo "Setting up the swap partition..."

      if [ "$IS_UEFI" = "yes" ]; then
        mkswap "${DISK}2"
        swapon "${DISK}2"
      else
        mkswap "${DISK}1"
        swapon "${DISK}1"
      fi

      echo "Swap partition has been enabled"
    elif [ "$SWAP_TYPE" = "file" ]; then
      echo "Setting up the swap file..."

      dd if=/dev/zero of=/mnt/swapfile bs=1M count=$(expr "$SWAP_SIZE" \* 1024) status=progress
      chmod 0600 /mnt/swapfile

      mkswap -U clear /mnt/swapfile
      swapon /mnt/swapfile
      free -m

      echo "Swap file has been enabled"
    else
      echo "Skipping swap, unknown swap type $SWAP_TYPE"
    fi
  else
    echo "Swap has been skipped"
  fi
}

create_fstab () {
  echo "Creating the file system table..."

  mkdir -p /mnt/etc
  genfstab -U /mnt >> /mnt/etc/fstab

  echo "The file system table has been created"
}

report () {
  echo -e "Disk layout is now set to:\n"

  parted --script "$DISK" print | awk '{print " "$0}'

  lsblk "$DISK" -o NAME,SIZE,TYPE,MOUNTPOINTS | awk '{print " "$0}'
}

echo -e "\nStarting disk partitioning..."

source "$OPTIONS"

unmount_all &&
  create_partitions &&
  format_partitions &&
  mount_filesystem &&
  make_swap &&
  create_fstab &&
  report

echo -e "\nDisk partitioning has been completed"
echo "Moving to the next process..."
sleep 5
