#!/bin/bash

set -Eeo pipefail

source /opt/stack/scripts/utils.sh

# Erases all table data of the installation disk.
wipe_disk () {
  echo 'Wiping disk data and file system...'

  echo 'Making sure everything is unmounted...'

  swapoff --all
  umount --lazy /mnt

  echo 'Unmounting process has been completed'

  echo 'Start now erasing disk data...'

  local disk=''
  disk="$(get_setting 'disk')" || exit 1

  wipefs -a "${disk}"

  if has_failed; then
    echo "Unable to erase data on disk ${disk}"
    exit 1
  fi

  echo -e 'Disk erasing has been completed\n'
}

# Creates GPT partitions for systems supporting UEFI.
create_gpt_partitions () {
  echo 'Creating a clean GPT partition table...'

  local disk=''
  disk="$(get_setting 'disk')" || exit 1

  parted --script "${disk}" mklabel gpt || exit 1

  local start=1
  local end=501

  parted --script "${disk}" mkpart 'Boot' fat32 "${start}MiB" "${end}MiB" || exit 1
  parted --script "${disk}" set 1 boot on || exit 1

  echo 'Boot partition has been created'

  start=${end}

  if is_setting 'swap_on' 'yes' && is_setting 'swap_type' 'partition'; then
    local swap_size=0
    swap_size=$(get_setting 'swap_size') || exit 1

    end=$((start + (swap_size * 1024)))

    parted --script "${disk}" mkpart 'Swap' linux-swap "${start}Mib" "${end}Mib" || exit 1

    echo 'Swap partition has been created'

    start=${end}
  fi

  parted --script "${disk}" mkpart 'Root' ext4 "${start}Mib" 100% || exit 1

  echo 'Root partition has been created'
}

# Creates MBR partitions for systems don't support UEFI.
create_mbr_partitions () {
  echo 'Creating a clean MBR partition table...'

  local disk=''
  disk="$(get_setting 'disk')" || exit 1

  parted --script "${disk}" mklabel msdos || exit 1

  local start=1
  local root_index=1

  if is_setting 'swap_on' 'yes' && is_setting 'swap_type' 'partition'; then
    local swap_size=0
    swap_size=$(get_setting 'swap_size') || exit 1

    local end=$((start + (swap_size * 1024)))

    parted --script "${disk}" mkpart primary linux-swap "${start}Mib" "${end}Mib" || exit 1

    echo 'Swap partition has been created'

    start=${end}
    root_index=2
  fi

  parted --script "${disk}" mkpart primary ext4 "${start}Mib" 100% || exit 1
  parted --script "${disk}" set "${root_index}" boot on || exit 1

  echo 'Root partition has been created'
}

# Creates the system partitions on the installation disk.
create_partitions () {
  echo 'Starting the disk partitioning...'

  if is_setting 'uefi_mode' 'yes'; then
    create_gpt_partitions || exit 1
  else
    create_mbr_partitions || exit 1
  fi

  echo 'Disk partitioning has been completed'
}

# Formats the partitions of the installation disk.
format_partitions () {
  echo 'Start formating partitions...'

  local disk=''
  disk="$(get_setting 'disk')" || exit 1

  local postfix=''
  if match "${disk}" '^/dev/nvme'; then
    postfix='p'
  fi

  if is_setting 'uefi_mode' 'yes'; then
    echo 'Formating boot partition...'

    mkfs.fat -F 32 "${disk}${postfix}1" || exit 1

    echo 'Formating root partition...'

    local root_index=2

    if is_setting 'swap_on' 'yes' && is_setting 'swap_type' 'partition'; then
      root_index=3
    fi

    mkfs.ext4 -F "${disk}${postfix}${root_index}" || exit 1
  else
    echo 'Formating root partition...'

    local root_index=1

    if is_setting 'swap_on' 'yes' && is_setting 'swap_type' 'partition'; then
      root_index=2
    fi

    mkfs.ext4 -F "${disk}${postfix}${root_index}" || exit 1
  fi

  echo 'Formating has been completed'
}

# Mounts the disk partitions of the isntallation disk.
mount_file_system () {
  echo 'Mounting disk partitions...'
  
  local disk=''
  disk="$(get_setting 'disk')" || exit 1

  local postfix=''
  if match "${disk}" '/dev/^nvme'; then
    postfix='p'
  fi

  local mount_opts='relatime,commit=60'

  if is_setting 'uefi_mode' 'yes'; then
    local root_index=2

    if is_setting 'swap_on' 'yes' && is_setting 'swap_type' 'partition'; then
      root_index=3
    fi

    mount -o "${mount_opts}" "${disk}${postfix}${root_index}" /mnt || exit 1

    echo 'Root partition mounted'

    mount --mkdir "${disk}${postfix}1" /mnt/boot || exit 1

    echo 'Boot partition mounted'
  else
    local root_index=1

    if is_setting 'swap_on' 'yes' && is_setting 'swap_type' 'partition'; then
      root_index=2
    fi

    mount -o "${mount_opts}" "${disk}${postfix}${root_index}" /mnt || exit 1

    echo 'Root partition mounted'
  fi

  echo 'Mounting has been completed'
}

# Creates the swap space.
make_swap_space () {
  if is_setting 'swap_on' 'no'; then
    echo 'Swap space has been disabled'

    return 0
  fi

  echo 'Setting up the swap space...'

  local disk=''
  disk="$(get_setting 'disk')" || exit 1

  local postfix=''
  if match "${disk}" '/dev/^nvme'; then
    postfix='p'
  fi

  if is_setting 'swap_type' 'partition'; then
    echo 'Setting up the swap partition...'

    local swap_index=1

    if is_setting 'uefi_mode' 'yes'; then
      swap_index=2
    fi

    mkswap "${disk}${postfix}${swap_index}" || exit 1
    swapon "${disk}${postfix}${swap_index}" || exit 1

    echo 'Swap partition has been enabled'
  elif is_setting 'swap_type' 'file'; then
    echo 'Setting up the swap file...'

    local swap_size=0
    swap_size=$(get_setting 'swap_size' | jq -cer '. * 1024') || exit 1

    local swap_file='/mnt/swapfile'

    dd if=/dev/zero of=${swap_file} bs=1M count=${swap_size} status=progress || exit 1
    chmod 0600 ${swap_file}

    mkswap -U clear ${swap_file} || exit 1
    swapon ${swap_file} || exit 1
    free -m

    echo 'Swap file has been enabled'
  else
    echo 'Skipping swap space, unknown or invalid swap type'
  fi
}

# Creates the file system table.
create_file_system_table () {
  echo 'Creating the file system table...'

  mkdir -p /mnt/etc || exit 1
  genfstab -U /mnt > /mnt/etc/fstab || exit 1

  echo 'The file system table has been created'
}

# Prints an overall report of the installation disk.
report () {
  echo -e 'Disk layout is now set to:\n'

  local disk=''
  disk="$(get_setting 'disk')" || exit 1

  parted --script "${disk}" print | awk '{print " "$0}'

  lsblk "${disk}" -o NAME,SIZE,TYPE,MOUNTPOINTS | awk '{print " "$0}'
}

echo -e "\nInstallation process started at $(date)"
echo 'Starting disk partitioning...'

wipe_disk &&
  create_partitions &&
  format_partitions &&
  mount_file_system &&
  make_swap_space &&
  create_file_system_table &&
  report

echo -e '\nDisk partitioning has been completed'
echo 'Moving to the bootstrap process...'
sleep 5
