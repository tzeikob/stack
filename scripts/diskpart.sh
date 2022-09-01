#!/usr/bin/env bash

create_partitions () {
  if [ "$IS_UEFI" = "yes" ]; then
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
  else
    echo "Creating a clean MBR partition table..."

    parted --script $DISK mklabel msdos

    local FROM=1

    if [ "$SWAP" = "yes" ] && [ "$SWAP_TYPE" = "partition" ]; then
      local TO=$((FROM + (SWAP_SIZE * 1024)))

      parted --script $DISK mkpart primary linux-swap ${FROM}Mib ${TO}Mib

      echo "Swap partition created successfully"

      FROM=$TO
    fi

    parted --script $DISK mkpart primary ext4 ${FROM}Mib 100%
    parted --script $DISK set 1 boot on

    echo "Root partition created successfully"
  fi

  echo -e "\nPartitioning table is set to:"

  parted --script $DISK print | awk '{print " "$0}'

  echo "Disk partitioning has been completed"
}

format_them () {
  echo -e "\nStart formating partitions..."

  if [ "$IS_UEFI" = "yes" ]; then
    mkfs.fat -F 32 ${DISK}1

    if [ "$SWAP" = "yes" ] && [ "$SWAP_TYPE" = "partition" ]; then
      mkswap ${DISK}2
      mkfs.ext4 -F -q ${DISK}3
    else
      mkfs.ext4 -F -q ${DISK}2
    fi
  else
    if [ "$SWAP" = "yes" ] && [ "$SWAP_TYPE" = "partition" ]; then
      mkswap ${DISK}1
      mkfs.ext4 -F -q ${DISK}2
    else
      mkfs.ext4 -F -q ${DISK}1
    fi
  fi

  echo "Formating has been completed successfully"
}

mount_them () {
  echo -e "\nMounting disk partitions..."

  if [ "$IS_UEFI" = "yes" ]; then
    if [ "$SWAP" = "yes" ] && [ "$SWAP_TYPE" = "partition" ]; then
      swapon ${DISK}2
      mount ${DISK}3 /mnt
    else
      mount ${DISK}2 /mnt
    fi

    mount --mkdir ${DISK}1 /mnt/boot
  else
    if [ "$SWAP" = "yes" ] && [ "$SWAP_TYPE" = "partition" ]; then
      swapon ${DISK}1
      mount ${DISK}2 /mnt
    else
      mount ${DISK}1 /mnt
    fi
  fi

  echo "Mounting has been completed"
}

report () {
  echo -e "\nDisk layout is now set to:"

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
