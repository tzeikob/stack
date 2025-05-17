#!/bin/bash

set -Eeo pipefail

source src/commons/error.sh
source src/commons/logger.sh
source src/commons/math.sh
source src/commons/validators.sh
source src/commons/math.sh

SETTINGS_FILE=./settings.json

# Erases all table data of the installation disk.
wipe_disk () {
  log INFO 'Wiping disk data and file system...'

  swapoff --all 2>&1 ||
    abort ERROR 'Unable to set swap off.'

  log INFO 'Swap set to off.'

  log INFO 'Making sure everything is unmounted...'

  if mountpoint -q /mnt; then
    umount --lazy /mnt 2>&1 ||
      abort ERROR 'Unable to unmount the /mnt folder.'

    log INFO 'Folder /mnt has been unmounted.'
  else
    log INFO 'Folder /mnt is not mounted.'
  fi

  log INFO 'Start now erasing disk data...'

  local disk=''
  disk="$(jq -cer '.disk' "${SETTINGS_FILE}")" ||
    abort ERROR 'Unable to read disk setting.'

  wipefs -a "${disk}" 2>&1 ||
    abort ERROR 'Failed to wipe the disk file system.'

  log INFO 'Disk data have been erased.'
}

# Creates GPT partitions for systems supporting UEFI.
create_gpt_partitions () {
  log INFO 'Creating a clean GPT partition table...'

  local disk=''
  disk="$(jq -cer '.disk' "${SETTINGS_FILE}")" ||
    abort ERROR 'Unable to read disk setting.'

  parted --script "${disk}" mklabel gpt 2>&1 ||
    abort ERROR 'Failed to create partition table.'

  log INFO 'Partition table has been created.'

  local start_from=1
  local end_at=501

  log INFO 'Creating the boot partition...'

  parted --script "${disk}" mkpart 'Boot' fat32 "${start_from}MiB" "${end_at}MiB" 2>&1 ||
    abort ERROR 'Failed to create boot partition.'

  log INFO 'Boot partition has been created.'

  parted --script "${disk}" set 1 boot on 2>&1 ||
    abort ERROR 'Failed to set boot partition on.'

  start_from=${end_at}

  local swap_on=''
  swap_on="$(jq -cer '.swap_on' "${SETTINGS_FILE}")" ||
    abort ERROR 'Failed to read the swap_on setting.'

  if is_yes "${swap_on}"; then
    local swap_type=''
    swap_type="$(jq -cer '.swap_type' "${SETTINGS_FILE}")" ||
      abort ERROR 'Failed to read the swap_type setting.'

    if equals "${swap_type}" 'partition'; then
      local swap_size=0
      swap_size=$(jq -cer '.swap_size' "${SETTINGS_FILE}") ||
        abort ERROR 'Unable to read swap_size setting.'

      end_at=$(calc "${start_from} + (${swap_size} * 1024)")

      log INFO 'Creating the swap partition...'

      parted --script "${disk}" mkpart 'Swap' linux-swap "${start_from}Mib" "${end_at}Mib" 2>&1 ||
        abort ERROR 'Failed to create swap partition.'

      log INFO 'Swap partition has been created.'

      start_from=${end_at}
    fi
  fi

  log INFO 'Creating the root partition...'

  parted --script "${disk}" mkpart 'Root' ext4 "${start_from}Mib" 100% 2>&1 ||
    abort ERROR 'Failed to create root partition.'

  log INFO 'Root partition has been created.'
}

# Creates MBR partitions for systems don't support UEFI.
create_mbr_partitions () {
  log INFO 'Creating a clean MBR partition table...'

  local disk=''
  disk="$(jq -cer '.disk' "${SETTINGS_FILE}")" ||
    abort ERROR 'Unable to read disk setting.'

  parted --script "${disk}" mklabel msdos 2>&1 ||
    abort ERROR 'Failed to create partition table.'

  log INFO 'Partition table has been created.'

  local start_from=1
  local root_index=1

  local swap_on=''
  swap_on="$(jq -cer '.swap_on' "${SETTINGS_FILE}")" ||
    abort ERROR 'Failed to read the swap_on setting.'

  if is_yes "${swap_on}"; then
    local swap_type=''
    swap_type="$(jq -cer '.swap_type' "${SETTINGS_FILE}")" ||
    abort ERROR 'Failed to read the swap_type setting.'

    if equals "${swap_type}" 'partition'; then
      local swap_size=0
      swap_size=$(jq -cer '.swap_size' "${SETTINGS_FILE}") ||
        abort ERROR 'Unable to read swap_size setting.'

      local end_at=0
      end_at=$(calc "${start_from} + (${swap_size} * 1024)")

      log INFO 'Creating the swap partition...'

      parted --script "${disk}" mkpart primary linux-swap "${start_from}Mib" "${end_at}Mib" 2>&1 ||
        abort ERROR 'Failed to create swap partition.'

      log INFO 'Swap partition has been created.'

      start_from=${end_at}
      root_index=2
    fi
  fi

  log INFO 'Creating the root partition...'

  parted --script "${disk}" mkpart primary ext4 "${start_from}Mib" 100% 2>&1 ||
    abort ERROR 'Failed to create root partition.'

  log INFO 'Root partition has been created.'

  parted --script "${disk}" set "${root_index}" boot on 2>&1 ||
    abort ERROR 'Failed to set root as boot partition.'

  log INFO 'Root partition set as boot partition.'
}

# Creates the system partitions on the installation disk.
create_partitions () {
  log INFO 'Creating disk partitions...'

  local uefi_mode=''
  uefi_mode="$(jq -cer '.uefi_mode' "${SETTINGS_FILE}")" ||
    abort ERROR 'Failed to read the uefi_mode setting.'

  if is_yes "${uefi_mode}"; then
    create_gpt_partitions ||
      abort ERROR 'Failed to create GPT partitions.'
  else
    create_mbr_partitions ||
      abort ERROR 'Failed to create MBR partitions.'
  fi

  log INFO 'Disk partitions have been created.'
}

# Formats the partitions of the installation disk.
format_partitions () {
  log INFO 'Formatting disk partitions...'

  local disk=''
  disk="$(jq -cer '.disk' "${SETTINGS_FILE}")" ||
    abort ERROR 'Unable to read disk setting.'

  # Append prefix for each partition of nvme disks
  local postfix=''
  if match "${disk}" '^/dev/nvme'; then
    postfix='p'
  fi

  local uefi_mode=''
  uefi_mode="$(jq -cer '.uefi_mode' "${SETTINGS_FILE}")" ||
    abort ERROR 'Failed to read the uefi_mode setting.'

  local swap_on=''
  swap_on="$(jq -cer '.swap_on' "${SETTINGS_FILE}")" ||
    abort ERROR 'Failed to read the swap_on setting.'

  if is_yes "${uefi_mode}"; then
    log INFO 'Formating the boot partition...'

    mkfs.fat -F 32 "${disk}${postfix}1" 2>&1 ||
      abort ERROR 'Failed to format boot partition.'

    log INFO 'Boot partition has been formatted.'

    local root_index=2

    if is_yes "${swap_on}"; then
      local swap_type=''
      swap_type="$(jq -cer '.swap_type' "${SETTINGS_FILE}")" ||
        abort ERROR 'Failed to read the swap_type setting.'

      if equals "${swap_type}" 'partition'; then
        root_index=3
      fi
    fi

    log INFO 'Formating the root partition...'

    mkfs.ext4 -F "${disk}${postfix}${root_index}" 2>&1 ||
      abort ERROR 'Failed to format root partition.'

    log INFO 'Root partition has been formatted.'
  else
    local root_index=1

    if is_yes "${swap_on}"; then
      local swap_type=''
      swap_type="$(jq -cer '.swap_type' "${SETTINGS_FILE}")" ||
        abort ERROR 'Failed to read the swap_type setting.'

      if equals "${swap_type}" 'partition'; then
        root_index=2
      fi
    fi

    log INFO 'Formating root partition...'

    mkfs.ext4 -F "${disk}${postfix}${root_index}" 2>&1 ||
      abort ERROR 'Failed to format root partition.'

    log INFO 'Root partition has been formatted.'
  fi

  log INFO 'Formating has been completed.'
}

# Mounts the disk partitions of the installation disk.
mount_file_system () {
  log INFO 'Mounting disk partitions...'
  
  local disk=''
  disk="$(jq -cer '.disk' "${SETTINGS_FILE}")" ||
    abort ERROR 'Unable to read disk setting.'

  # Append prefix for each partition of nvme disks
  local postfix=''
  if match "${disk}" '^/dev/nvme'; then
    postfix='p'
  fi

  local mount_opts='relatime,commit=60'

  local uefi_mode=''
  uefi_mode="$(jq -cer '.uefi_mode' "${SETTINGS_FILE}")" ||
    abort ERROR 'Failed to read the uefi_mode setting.'

  local swap_on=''
  swap_on="$(jq -cer '.swap_on' "${SETTINGS_FILE}")" ||
    abort ERROR 'Failed to read the swap_on setting.'

  if is_yes "${uefi_mode}"; then
    local root_index=2

    if is_yes "${swap_on}"; then
      local swap_type=''
      swap_type="$(jq -cer '.swap_type' "${SETTINGS_FILE}")" ||
        abort ERROR 'Failed to read the swap_type setting.'

      if equals "${swap_type}" 'partition'; then
        root_index=3
      fi
    fi

    mount -o "${mount_opts}" "${disk}${postfix}${root_index}" /mnt 2>&1 ||
      abort ERROR 'Failed to mount root partition to /mnt.'

    log INFO 'Root partition has been mounted to /mnt.'

    mount --mkdir "${disk}${postfix}1" /mnt/boot 2>&1 ||
      abort ERROR 'Failed to mount boot partition to /mnt/boot.'

    log INFO 'Boot partition mounted to /mnt/boot.'
  else
    local root_index=1

    if is_yes "${swap_on}"; then
      local swap_type=''
      swap_type="$(jq -cer '.swap_type' "${SETTINGS_FILE}")" ||
        abort ERROR 'Failed to read the swap_type setting.'

      if equals "${swap_type}" 'partition'; then
        root_index=2
      fi
    fi

    mount -o "${mount_opts}" "${disk}${postfix}${root_index}" /mnt 2>&1 ||
      abort ERROR 'Failed to mount root partition to /mnt.'

    log INFO 'Root partition mounted to /mnt.'
  fi

  log INFO 'Mounting partitions has been completed.'
}

# Creates the swap space.
make_swap_space () {
  local swap_on=''
  swap_on="$(jq -cer '.swap_on' "${SETTINGS_FILE}")" ||
    abort ERROR 'Failed to read the swap_on setting.'

  if is_no "${swap_on}"; then
    log INFO 'Swap space has been disabled.'
    return 0
  fi

  log INFO 'Setting up the swap space...'

  local disk=''
  disk="$(jq -cer '.disk' "${SETTINGS_FILE}")" ||
    abort ERROR 'Unable to read disk setting.'

  # Append prefix for each partition of nvme disks
  local postfix=''
  if match "${disk}" '^/dev/nvme'; then
    postfix='p'
  fi

  local swap_type=''
  swap_type="$(jq -cer '.swap_type' "${SETTINGS_FILE}")" ||
    abort ERROR 'Failed to read the swap_type setting.'

  if equals "${swap_type}" 'partition'; then
    local swap_index=1

    local uefi_mode=''
    uefi_mode="$(jq -cer '.uefi_mode' "${SETTINGS_FILE}")" ||
      abort ERROR 'Failed to read the uefi_mode setting.'

    if is_yes "${uefi_mode}"; then
      swap_index=2
    fi

    log INFO 'Setting up the swap partition...'

    mkswap "${disk}${postfix}${swap_index}" 2>&1 &&
      swapon "${disk}${postfix}${swap_index}" 2>&1 ||
      abort ERROR 'Failed to enable swap partition.'

    log INFO 'Swap partition has been enabled.'
  elif equals "${swap_type}" 'file'; then
    local swap_size=0
    swap_size=$(jq -cer '.swap_size * 1024' "${SETTINGS_FILE}") ||
      abort ERROR 'Unable to read swap_size setting.'

    local swap_file='/mnt/swapfile'

    log INFO 'Setting up the swap file...'

    dd if=/dev/zero of=${swap_file} bs=1M count=${swap_size} status=progress 2>&1 &&
      chmod 0600 ${swap_file} &&
      mkswap -U clear ${swap_file} 2>&1 &&
      swapon ${swap_file} 2>&1 &&
      free -m 2>&1 ||
      abort ERROR "Failed to set swap file to ${swap_file}."

    log INFO "Swap file has been set to ${swap_file}."
  else
    log INFO 'Skipping swap space, invalid swap type.'
  fi
}

# Creates the file system table.
create_file_system_table () {
  log INFO 'Creating the file system table...'

  mkdir -p /mnt/etc &&
    genfstab -U /mnt > /mnt/etc/fstab 2>&1 ||
    abort ERROR 'Failed to create file system table.'

  log INFO 'File system table has been created.'
}

# Prints an overall report of the installation disk.
report () {
  log INFO 'Disk layout is now set to:\n'

  local disk=''
  disk="$(jq -cer '.disk' "${SETTINGS_FILE}")" ||
    abort ERROR 'Unable to read disk setting.'

  parted --script "${disk}" print 2>&1 |
    awk '{print " "$0}' || abort ERROR 'Unable to list disk info.'

  lsblk "${disk}" -o NAME,SIZE,TYPE,MOUNTPOINTS 2>&1 |
    awk '{print " "$0}' || abort ERROR 'Unable to list disk info.'
}

# Prints dummy log lines to fake tqdm progress bar, when a
# task gives less lines than it is expected to print and so
# it resolves with fake lines to emulate completion.
# Arguments:
#  total: the log lines the task is expected to print
# Outputs:
#  Fake dummy log lines.
resolve () {
  local total="${1}"

  local log_file='/var/log/stack/installer/diskpart.log'

  local lines=0
  lines=$(cat "${log_file}" | wc -l)

  local fake_lines=0
  fake_lines=$(calc "${total} - ${lines}")

  seq ${fake_lines} | xargs -I -- echo '~'
}

log INFO 'Script diskpart.sh started.'
log INFO 'Starting the disk partitioning...'

wipe_disk &&
  create_partitions &&
  format_partitions &&
  mount_file_system &&
  make_swap_space &&
  create_file_system_table &&
  report ||
  abort

log INFO 'Script diskpart.sh has finished.'

resolve 90 && sleep 2
