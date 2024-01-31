#!/bin/bash

set -Eeo pipefail

source /opt/stack/scripts/utils.sh

# Erases all table data of the installation disk.
wipe_disk () {
  log 'Wiping disk data and file system...'

  OUTPUT="$(
    swapoff --all 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  log 'Making sure everything is unmounted...'

  if mountpoint -q /mnt; then
    OUTPUT="$(
      umount --lazy /mnt 2>&1
    )" || fail

    log -t file "${OUTPUT}"

    log 'Folder /mnt has been unmounted'
  else
    log 'Folder /mnt is not mounted'
  fi

  log 'Start now erasing disk data...'

  local disk=''
  disk="$(get_setting 'disk')" || fail

  OUTPUT="$(
    wipefs -a "${disk}" 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  log 'Disk erasing has been completed\n'
}

# Creates GPT partitions for systems supporting UEFI.
create_gpt_partitions () {
  log 'Creating a clean GPT partition table...'

  local disk=''
  disk="$(get_setting 'disk')" || fail

  OUTPUT="$(
    parted --script "${disk}" mklabel gpt 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  local start=1
  local end=501

  OUTPUT="$(
    parted --script "${disk}" mkpart 'Boot' fat32 "${start}MiB" "${end}MiB" 2>&1 &&
      parted --script "${disk}" set 1 boot on 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  log 'Boot partition has been created'

  start=${end}

  if is_setting 'swap_on' 'yes' && is_setting 'swap_type' 'partition'; then
    local swap_size=0
    swap_size=$(get_setting 'swap_size') || fail

    end=$((start + (swap_size * 1024)))

    OUTPUT="$(
      parted --script "${disk}" mkpart 'Swap' linux-swap "${start}Mib" "${end}Mib" 2>&1
    )" || fail

    log -t file "${OUTPUT}"

    log 'Swap partition has been created'

    start=${end}
  fi

  OUTPUT="$(
    parted --script "${disk}" mkpart 'Root' ext4 "${start}Mib" 100% 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  log 'Root partition has been created'
}

# Creates MBR partitions for systems don't support UEFI.
create_mbr_partitions () {
  log 'Creating a clean MBR partition table...'

  local disk=''
  disk="$(get_setting 'disk')" || fail

  OUTPUT="$(
    parted --script "${disk}" mklabel msdos 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  local start=1
  local root_index=1

  if is_setting 'swap_on' 'yes' && is_setting 'swap_type' 'partition'; then
    local swap_size=0
    swap_size=$(get_setting 'swap_size') || fail

    local end=$((start + (swap_size * 1024)))

    OUTPUT="$(
      parted --script "${disk}" mkpart primary linux-swap "${start}Mib" "${end}Mib" 2>&1
    )" || fail

    log -t file "${OUTPUT}"

    log 'Swap partition has been created'

    start=${end}
    root_index=2
  fi

  OUTPUT="$(
    parted --script "${disk}" mkpart primary ext4 "${start}Mib" 100% 2>&1 &&
      parted --script "${disk}" set "${root_index}" boot on 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  log 'Root partition has been created'
}

# Creates the system partitions on the installation disk.
create_partitions () {
  log 'Starting the disk partitioning...'

  if is_setting 'uefi_mode' 'yes'; then
    create_gpt_partitions || fail
  else
    create_mbr_partitions || fail
  fi

  log 'Disk partitioning has been completed'
}

# Formats the partitions of the installation disk.
format_partitions () {
  log 'Start formating partitions...'

  local disk=''
  disk="$(get_setting 'disk')" || fail

  local postfix=''
  if match "${disk}" '^/dev/nvme'; then
    postfix='p'
  fi

  if is_setting 'uefi_mode' 'yes'; then
    log 'Formating boot partition...'

    OUTPUT="$(
      mkfs.fat -F 32 "${disk}${postfix}1" 2>&1
    )" || fail

    log -t file "${OUTPUT}"

    log 'Formating root partition...'

    local root_index=2

    if is_setting 'swap_on' 'yes' && is_setting 'swap_type' 'partition'; then
      root_index=3
    fi

    OUTPUT="$(
      mkfs.ext4 -F "${disk}${postfix}${root_index}" 2>&1
    )" || fail

    log -t file "${OUTPUT}"
  else
    log 'Formating root partition...'

    local root_index=1

    if is_setting 'swap_on' 'yes' && is_setting 'swap_type' 'partition'; then
      root_index=2
    fi

    OUTPUT="$(
      mkfs.ext4 -F "${disk}${postfix}${root_index}" 2>&1
    )" || fail

    log -t file "${OUTPUT}"
  fi

  log 'Formating has been completed'
}

# Mounts the disk partitions of the isntallation disk.
mount_file_system () {
  log 'Mounting disk partitions...'
  
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

    OUTPUT="$(
      mount -o "${mount_opts}" "${disk}${postfix}${root_index}" /mnt 2>&1
    )" || fail

    log -t file "${OUTPUT}"

    log 'Root partition mounted'

    OUTPUT="$(
      mount --mkdir "${disk}${postfix}1" /mnt/boot 2>&1
    )" || fail

    log -t file "${OUTPUT}"

    log 'Boot partition mounted'
  else
    local root_index=1

    if is_setting 'swap_on' 'yes' && is_setting 'swap_type' 'partition'; then
      root_index=2
    fi

    OUTPUT="$(
      mount -o "${mount_opts}" "${disk}${postfix}${root_index}" /mnt 2>&1
    )" || fail

    log -t file "${OUTPUT}"

    log 'Root partition mounted'
  fi

  log 'Mounting has been completed'
}

# Creates the swap space.
make_swap_space () {
  if is_setting 'swap_on' 'no'; then
    log 'Swap space has been disabled'

    return 0
  fi

  log 'Setting up the swap space...'

  local disk=''
  disk="$(get_setting 'disk')" || fail

  local postfix=''
  if match "${disk}" '/dev/^nvme'; then
    postfix='p'
  fi

  if is_setting 'swap_type' 'partition'; then
    log 'Setting up the swap partition...'

    local swap_index=1

    if is_setting 'uefi_mode' 'yes'; then
      swap_index=2
    fi

    OUTPUT="$(
      mkswap "${disk}${postfix}${swap_index}" 2>&1 &&
        swapon "${disk}${postfix}${swap_index}" 2>&1
    )" || fail

    log -t file "${OUTPUT}"

    log 'Swap partition has been enabled'
  elif is_setting 'swap_type' 'file'; then
    log 'Setting up the swap file...'

    local swap_size=0
    swap_size=$(get_setting 'swap_size' | jq -cer '. * 1024') || fail

    local swap_file='/mnt/swapfile'

    OUTPUT="$(
      dd if=/dev/zero of=${swap_file} bs=1M count=${swap_size} status=progress 2>&1 &&
        chmod 0600 ${swap_file} 2>&1 &&
        mkswap -U clear ${swap_file} 2>&1 &&
        swapon ${swap_file} 2>&1 &&
        free -m 2>&1
    )" || fail

    log -t file "${OUTPUT}"

    log 'Swap file has been enabled'
  else
    log 'Skipping swap space, unknown or invalid swap type'
  fi
}

# Creates the file system table.
create_file_system_table () {
  log 'Creating the file system table...'

  OUTPUT="$(
    mkdir -p /mnt/etc 2>&1 &&
      genfstab -U /mnt > /mnt/etc/fstab
  )" || fail

  log -t file "${OUTPUT}"

  log 'The file system table has been created'
}

# Prints an overall report of the installation disk.
report () {
  log 'Disk layout is now set to:\n'

  local disk=''
  disk="$(get_setting 'disk')" || fail

  OUTPUT="$(
    parted --script "${disk}" print  2>&1 | awk '{print " "$0}'
  )" || fail

  log "${OUTPUT}"

  OUTPUT="$(
    lsblk "${disk}" -o NAME,SIZE,TYPE,MOUNTPOINTS  2>&1 | awk '{print " "$0}'
  )" || fail

  log "${OUTPUT}"
}

log "\nInstallation process started at $(date -u)"
log 'Starting disk partitioning...'

wipe_disk &&
  create_partitions &&
  format_partitions &&
  mount_file_system &&
  make_swap_space &&
  create_file_system_table &&
  report

sleep 3
