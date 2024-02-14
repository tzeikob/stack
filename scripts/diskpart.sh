#!/bin/bash

set -Eeo pipefail

source /opt/stack/scripts/utils.sh

# Erases all table data of the installation disk.
wipe_disk () {
  log 'Wiping disk data and file system...'

  swapoff --all 2>&1 ||
    fail 'Unable to set swap off'

  log 'Swap set to off'

  log 'Making sure everything is unmounted...'

  if mountpoint -q /mnt; then
    umount --lazy /mnt 2>&1 ||
      fail 'Unable to unmount the /mnt folder'

    log 'Folder /mnt has been unmounted'
  else
    log 'Folder /mnt is not mounted'
  fi

  log 'Start now erasing disk data...'

  local disk=''
  disk="$(get_setting 'disk')" || fail 'Unable to read disk setting'

  wipefs -a "${disk}" 2>&1 ||
    fail 'Failed to wipe the disk file system'

  log 'Disk data have been erased'
}

# Creates GPT partitions for systems supporting UEFI.
create_gpt_partitions () {
  log 'Creating a clean GPT partition table...'

  local disk=''
  disk="$(get_setting 'disk')" || fail 'Unable to read disk setting'

  parted --script "${disk}" mklabel gpt 2>&1 ||
    fail 'Failed to create partition table'

  log 'Partition table has been created'

  local start=1
  local end=501

  log 'Creating the boot partition...'

  parted --script "${disk}" mkpart 'Boot' fat32 "${start}MiB" "${end}MiB" 2>&1 ||
    fail 'Failed to create boot partition'

  log 'Boot partition has been created'

  parted --script "${disk}" set 1 boot on 2>&1 ||
    fail 'Failed to set boot partition on'

  start=${end}

  if is_setting 'swap_on' 'yes' && is_setting 'swap_type' 'partition'; then
    local swap_size=0
    swap_size=$(get_setting 'swap_size') || fail 'Unable to read swap_size setting'

    end=$((start + (swap_size * 1024)))

    log 'Creating the swap partition...'

    parted --script "${disk}" mkpart 'Swap' linux-swap "${start}Mib" "${end}Mib" 2>&1 ||
      fail 'Failed to create swap partition'

    log 'Swap partition has been created'

    start=${end}
  fi

  log 'Creating the root partition...'

  parted --script "${disk}" mkpart 'Root' ext4 "${start}Mib" 100% 2>&1 ||
    fail 'Failed to create root partition'

  log 'Root partition has been created'
}

# Creates MBR partitions for systems don't support UEFI.
create_mbr_partitions () {
  log 'Creating a clean MBR partition table...'

  local disk=''
  disk="$(get_setting 'disk')" || fail 'Unable to read disk setting'

  parted --script "${disk}" mklabel msdos 2>&1 ||
    fail 'Failed to create partition table'

  log 'Partition table has been created'

  local start=1
  local root_index=1

  if is_setting 'swap_on' 'yes' && is_setting 'swap_type' 'partition'; then
    local swap_size=0
    swap_size=$(get_setting 'swap_size') || fail 'Unable to read swap_size setting'

    local end=$((start + (swap_size * 1024)))

    log 'Creating the swap partition...'

    parted --script "${disk}" mkpart primary linux-swap "${start}Mib" "${end}Mib" 2>&1 ||
      fail 'Failed to create swap partition'

    log 'Swap partition has been created'

    start=${end}
    root_index=2
  fi

  log 'Creating the root partition...'

  parted --script "${disk}" mkpart primary ext4 "${start}Mib" 100% 2>&1 ||
    fail 'Failed to create root partition'

  log 'Root partition has been created'

  parted --script "${disk}" set "${root_index}" boot on 2>&1 ||
    fail 'Failed to set root as boot partition'

  log 'Root partition set as boot partition'
}

# Creates the system partitions on the installation disk.
create_partitions () {
  log 'Creating disk partitions...'

  if is_setting 'uefi_mode' 'yes'; then
    create_gpt_partitions || fail
  else
    create_mbr_partitions || fail
  fi

  log 'Disk partitions have been created'
}

# Formats the partitions of the installation disk.
format_partitions () {
  log 'Formatting disk partitions...'

  local disk=''
  disk="$(get_setting 'disk')" || fail 'Unable to read disk setting'

  local postfix=''
  if match "${disk}" '^/dev/nvme'; then
    postfix='p'
  fi

  if is_setting 'uefi_mode' 'yes'; then
    log 'Formating the boot partition...'

    mkfs.fat -F 32 "${disk}${postfix}1" 2>&1 ||
      fail 'Failed to format boot partition'

    log 'Boot partition has been formatted'

    local root_index=2

    if is_setting 'swap_on' 'yes' && is_setting 'swap_type' 'partition'; then
      root_index=3
    fi

    log 'Formating the root partition...'

    mkfs.ext4 -F "${disk}${postfix}${root_index}" 2>&1 ||
      fail 'Failed to format root partition'

    log 'Root partition has been formatted'
  else
    local root_index=1

    if is_setting 'swap_on' 'yes' && is_setting 'swap_type' 'partition'; then
      root_index=2
    fi

    log 'Formating root partition...'

    mkfs.ext4 -F "${disk}${postfix}${root_index}" 2>&1 ||
      fail 'Failed to format root partition'

    log 'Root partition has been formatted'
  fi

  log 'Formating has been completed'
}

# Mounts the disk partitions of the isntallation disk.
mount_file_system () {
  log 'Mounting disk partitions...'
  
  local disk=''
  disk="$(get_setting 'disk')" || fail 'Unable to read disk setting'

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

    mount -o "${mount_opts}" "${disk}${postfix}${root_index}" /mnt 2>&1 ||
      fail 'Failed to mount root partition to /mnt'

    log 'Root partition has been mounted to /mnt'

    mount --mkdir "${disk}${postfix}1" /mnt/boot 2>&1 ||
      fail 'Failed to mount boot partition to /mnt/boot'

    log 'Boot partition mounted to /mnt/boot'
  else
    local root_index=1

    if is_setting 'swap_on' 'yes' && is_setting 'swap_type' 'partition'; then
      root_index=2
    fi

    mount -o "${mount_opts}" "${disk}${postfix}${root_index}" /mnt 2>&1 ||
      fail 'Failed to mount root partition to /mnt'

    log 'Root partition mounted to /mnt'
  fi

  log 'Mounting partitions has been completed'
}

# Creates the swap space.
make_swap_space () {
  if is_setting 'swap_on' 'no'; then
    log 'Swap space has been disabled'
    return 0
  fi

  log 'Setting up the swap space...'

  local disk=''
  disk="$(get_setting 'disk')" || fail 'Unable to read disk setting'

  local postfix=''
  if match "${disk}" '/dev/^nvme'; then
    postfix='p'
  fi

  if is_setting 'swap_type' 'partition'; then
    local swap_index=1

    if is_setting 'uefi_mode' 'yes'; then
      swap_index=2
    fi

    log 'Setting up the swap partition...'

    mkswap "${disk}${postfix}${swap_index}" 2>&1 &&
      swapon "${disk}${postfix}${swap_index}" 2>&1 ||
      fail 'Failed to enable swap partition'

    log 'Swap partition has been enabled'
  elif is_setting 'swap_type' 'file'; then
    local swap_size=0
    swap_size=$(get_setting 'swap_size' | jq -cer '. * 1024') ||
      fail 'Unable to read swap_size setting'

    local swap_file='/mnt/swapfile'

    log 'Setting up the swap file...'

    dd if=/dev/zero of=${swap_file} bs=1M count=${swap_size} status=progress 2>&1 &&
      chmod 0600 ${swap_file} &&
      mkswap -U clear ${swap_file} 2>&1 &&
      swapon ${swap_file} 2>&1 &&
      free -m 2>&1 ||
      fail "Failed to set swap file to ${swap_file}"

    log "Swap file has been set to ${swap_file}"
  else
    log 'Skipping swap space, invalid swap type'
  fi
}

# Creates the file system table.
create_file_system_table () {
  log 'Creating the file system table...'

  mkdir -p /mnt/etc &&
    genfstab -U /mnt > /mnt/etc/fstab 2>&1 ||
    fail 'Failed to create file system table'

  log 'File system table has been created'
}

# Prints an overall report of the installation disk.
report () {
  log 'Disk layout is now set to:\n'

  local disk=''
  disk="$(get_setting 'disk')" || fail 'Unable to read disk setting'

  parted --script "${disk}" print 2>&1 |
    awk '{print " "$0}' || fail 'Unable to list disk info'

  lsblk "${disk}" -o NAME,SIZE,TYPE,MOUNTPOINTS 2>&1 |
    awk '{print " "$0}' || fail 'Unable to list disk info'
}

# Resolves the installaction script by addressing
# some extra post execution tasks.
resolve () {
  # Read the current progress as the number of log lines
  local lines=0
  lines=$(cat /var/log/stack/diskpart.log | wc -l) ||
    fail 'Unable to read the current log lines'

  local total=90

  # Fill the log file with fake lines to trick tqdm bar on completion
  if [[ ${lines} -lt ${total} ]]; then
    local lines_to_append=0
    lines_to_append=$((total - lines))

    while [[ ${lines_to_append} -gt 0 ]]; do
      echo '~'
      sleep 0.15
      lines_to_append=$((lines_to_append - 1))
    done
  fi

  return 0
}

log 'Script diskpart.sh started'
log 'Starting the disk partitioning...'

wipe_disk &&
  create_partitions &&
  format_partitions &&
  mount_file_system &&
  make_swap_space &&
  create_file_system_table &&
  report

log 'Script diskpart.sh has finished'

resolve && sleep 3
