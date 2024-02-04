#!/bin/bash

set -Eeo pipefail

source /opt/stack/scripts/utils.sh

# Erases all table data of the installation disk.
wipe_disk () {
  echo -e 'Wiping disk data and file system...'

  swapoff --all || fail 'Unable to set swap off'

  echo -e 'Swap set to off'

  echo -e 'Making sure everything is unmounted...'

  if mountpoint -q /mnt; then
    umount --lazy /mnt || fail 'Unable to unmount the /mnt folder'

    echo -e 'Folder /mnt has been unmounted'
  else
    echo -e 'Folder /mnt is not mounted'
  fi

  echo -e 'Start now erasing disk data...'

  local disk=''
  disk="$(get_setting 'disk')" || fail

  wipefs -a "${disk}" || fail 'Failed to wipe the disk file system'

  echo -e 'Disk data have been erased'
}

# Creates GPT partitions for systems supporting UEFI.
create_gpt_partitions () {
  echo -e 'Creating a clean GPT partition table...'

  local disk=''
  disk="$(get_setting 'disk')" || fail

  parted --script "${disk}" mklabel gpt || fail 'Failed to create partition table'

  echo -e 'Partition table has been created'

  local start=1
  local end=501

  echo -e 'Creating the boot partition...'

  parted --script "${disk}" mkpart \
    'Boot' fat32 "${start}MiB" "${end}MiB" || fail 'Failed to create boot partition'

  echo -e 'Boot partition has been created'

  parted --script "${disk}" set 1 boot on || fail 'Failed to set boot partition on'

  start=${end}

  if is_setting 'swap_on' 'yes' && is_setting 'swap_type' 'partition'; then
    local swap_size=0
    swap_size=$(get_setting 'swap_size') || fail

    end=$((start + (swap_size * 1024)))

    echo -e 'Creating the swap partition...'

    parted --script "${disk}" mkpart \
      'Swap' linux-swap "${start}Mib" "${end}Mib" || fail 'Failed to create swap partition'

    echo -e 'Swap partition has been created'

    start=${end}
  fi

  echo -e 'Creating the root partition...'

  parted --script "${disk}" mkpart \
    'Root' ext4 "${start}Mib" 100% || fail 'Failed to create root partition'

  echo -e 'Root partition has been created'
}

# Creates MBR partitions for systems don't support UEFI.
create_mbr_partitions () {
  echo -e 'Creating a clean MBR partition table...'

  local disk=''
  disk="$(get_setting 'disk')" || fail

  parted --script "${disk}" mklabel msdos || fail 'Failed to create partition table'

  echo -e 'Partition table has been created'

  local start=1
  local root_index=1

  if is_setting 'swap_on' 'yes' && is_setting 'swap_type' 'partition'; then
    local swap_size=0
    swap_size=$(get_setting 'swap_size') || fail

    local end=$((start + (swap_size * 1024)))

    echo -e 'Creating the swap partition...'

    parted --script "${disk}" mkpart \
      primary linux-swap "${start}Mib" "${end}Mib" || fail 'Failed to create swap partition'

    echo -e 'Swap partition has been created'

    start=${end}
    root_index=2
  fi

  echo -e 'Creating the root partition...'

  parted --script "${disk}" mkpart \
    primary ext4 "${start}Mib" 100% || fail 'Failed to create root partition'

  echo -e 'Root partition has been created'

  parted --script "${disk}" set "${root_index}" boot on || fail 'Failed to set root as boot partition'

  echo -e 'Root partition set as boot partition'
}

# Creates the system partitions on the installation disk.
create_partitions () {
  echo -e 'Creating disk partitions...'

  if is_setting 'uefi_mode' 'yes'; then
    create_gpt_partitions || fail
  else
    create_mbr_partitions || fail
  fi

  echo -e 'Disk partitions have been created'
}

# Formats the partitions of the installation disk.
format_partitions () {
  echo -e 'Formatting disk partitions...'

  local disk=''
  disk="$(get_setting 'disk')" || fail

  local postfix=''
  if match "${disk}" '^/dev/nvme'; then
    postfix='p'
  fi

  if is_setting 'uefi_mode' 'yes'; then
    echo -e 'Formating the boot partition...'

    mkfs.fat -F 32 "${disk}${postfix}1" || fail 'Failed to format boot partition'

    echo -e 'Boot partition has been formatted'

    local root_index=2

    if is_setting 'swap_on' 'yes' && is_setting 'swap_type' 'partition'; then
      root_index=3
    fi

    echo -e 'Formating the root partition...'

    mkfs.ext4 -F "${disk}${postfix}${root_index}" || fail 'Failed to format root partition'

    echo -e 'Root partition has been formatted'
  else
    local root_index=1

    if is_setting 'swap_on' 'yes' && is_setting 'swap_type' 'partition'; then
      root_index=2
    fi

    echo -e 'Formating root partition...'

    mkfs.ext4 -F "${disk}${postfix}${root_index}" || fail 'Failed to format root partition'

    echo -e 'Root partition has been formatted'
  fi

  echo -e 'Formating has been completed'
}

# Mounts the disk partitions of the isntallation disk.
mount_file_system () {
  echo -e 'Mounting disk partitions...'
  
  local disk=''
  disk="$(get_setting 'disk')" || fail

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

    mount -o "${mount_opts}" \
      "${disk}${postfix}${root_index}" /mnt || fail 'Failed to mount root partition to /mnt'

    echo -e 'Root partition has been mounted to /mnt'

    mount --mkdir "${disk}${postfix}1" /mnt/boot || fail 'Failed to mount boot partition to /mnt/boot'

    echo -e 'Boot partition mounted to /mnt/boot'
  else
    local root_index=1

    if is_setting 'swap_on' 'yes' && is_setting 'swap_type' 'partition'; then
      root_index=2
    fi

    mount -o "${mount_opts}" \
      "${disk}${postfix}${root_index}" /mnt || fail 'Failed to mount root partition to /mnt'

    echo -e 'Root partition mounted to /mnt'
  fi

  echo -e 'Mounting partitions has been completed'
}

# Creates the swap space.
make_swap_space () {
  if is_setting 'swap_on' 'no'; then
    echo -e 'Swap space has been disabled'
    return 0
  fi

  echo -e 'Setting up the swap space...'

  local disk=''
  disk="$(get_setting 'disk')" || fail

  local postfix=''
  if match "${disk}" '/dev/^nvme'; then
    postfix='p'
  fi

  if is_setting 'swap_type' 'partition'; then
    local swap_index=1

    if is_setting 'uefi_mode' 'yes'; then
      swap_index=2
    fi

    echo -e 'Setting up the swap partition...'

    mkswap "${disk}${postfix}${swap_index}" &&
      swapon "${disk}${postfix}${swap_index}" || fail 'Failed to enable swap partition'

    echo -e 'Swap partition has been enabled'
  elif is_setting 'swap_type' 'file'; then
    local swap_size=0
    swap_size=$(get_setting 'swap_size' | jq -cer '. * 1024') || fail

    local swap_file='/mnt/swapfile'

    echo -e 'Setting up the swap file...'

    dd if=/dev/zero of=${swap_file} bs=1M count=${swap_size} status=progress &&
      chmod 0600 ${swap_file} &&
      mkswap -U clear ${swap_file} &&
      swapon ${swap_file} &&
      free -m  || fail "Failed to set swap file to ${swap_file}"

    echo -e "Swap file has been set to ${swap_file}"
  else
    echo -e "Skipping swap space, invalid swap type ${swap_type}"
  fi
}

# Creates the file system table.
create_file_system_table () {
  echo -e 'Creating the file system table...'

  mkdir -p /mnt/etc &&
    genfstab -U /mnt > /mnt/etc/fstab || fail 'Failed to create file system table'

  echo -e 'File system table has been created'
}

# Prints an overall report of the installation disk.
report () {
  echo -e 'Disk layout is now set to:\n'

  local disk=''
  disk="$(get_setting 'disk')" || fail

  parted --script "${disk}" print |
    awk '{print " "$0}' || fail 'Unable to list disk info'

  lsblk "${disk}" -o NAME,SIZE,TYPE,MOUNTPOINTS |
    awk '{print " "$0}' || fail 'Unable to list disk info'
}

echo -e 'Starting the disk partitioning...'

wipe_disk &&
  create_partitions &&
  format_partitions &&
  mount_file_system &&
  make_swap_space &&
  create_file_system_table &&
  report

sleep 3
