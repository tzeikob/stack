#!/bin/bash

set -Eeo pipefail

source /opt/stack/scripts/utils.sh

# Synchronizes the system clock to the current time.
sync_clock () {
  log 'Updating the system clock...'

  local timezone=''
  timezone="$(get_setting 'timezone')" || fail

  OUTPUT="$(
    timedatectl set-timezone "${timezone}" 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  log "Timezone has been set to ${timezone}"

  OUTPUT="$(
    timedatectl set-ntp true 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  log 'NTP mode has been enabled'

  while timedatectl status | grep -q 'System clock synchronized: no'; do
    sleep 1
  done

  OUTPUT="$(
    timedatectl status 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  log 'System clock has been updated'
}

# Sets the pacman mirrors list.
set_mirrors () {
  log 'Setting up pacman mirrors list...'

  local mirrors=''
  mirrors="$(get_setting 'mirrors' | jq -cer 'join(",")')" || fail

  OUTPUT="$(
    reflector --country "${mirrors}" --age 48 --sort age --latest 40 \
      --save /etc/pacman.d/mirrorlist 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  log "Pacman mirrors list set to ${mirrors}"
}

# Synchronizes package databases with the master.
sync_package_databases () {
  log 'Starting to synchronize package databases...'

  local lock_file='/var/lib/pacman/db.lck'

  if file_exists "${lock_file}"; then
    log 'Package databases seem to be locked'

    rm -f "${lock_file}" || fail

    log "Lock file ${lock_file} has been removed"
  fi

  local keyserver='hkp://keyserver.ubuntu.com'

  echo "keyserver ${keyserver}" >> /etc/pacman.d/gnupg/gpg.conf || fail

  log "GPG keyserver has been set to ${keyserver}"

  sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf || fail

  OUTPUT="$(
    pacman -Syy 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  log 'Package databases synchronized with the master'
}

# Updates the keyring package.
update_keyring () {
  log 'Updating keyring package...'

  OUTPUT="$(
    pacman -Sy --noconfirm archlinux-keyring 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  log 'Keyring has been updated successfully'
}

# Installs the linux kernels.
install_kernels () {
  log 'Installing the linux kernels...'

  local kernels=''
  kernels="$(get_setting 'kernels' | jq -cer 'join(" ")')" || fail

  local pckgs=''

  if match "${kernels}" 'stable'; then
    pckgs='linux linux-headers'
  fi

  if match "${kernels}" 'lts'; then
    pckgs+=' linux-lts linux-lts-headers'
  fi

  if is_empty "${pckgs}"; then
    fail 'No linux kernel packages set for installation'
  fi

  OUTPUT="$(
    pacstrap /mnt base ${pckgs} linux-firmware archlinux-keyring reflector rsync sudo jq 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  log 'Linux kernels have been installed'
}

# Grants the nopasswd permission to the wheel user group.
grant_permissions () {
  local rule='%wheel ALL=(ALL:ALL) NOPASSWD: ALL'

  sed -i "s/^# \(${rule}\)/\1/" /mnt/etc/sudoers || fail
}

# Copies the installation and the log files to the new system.
copy_installation_files () {
  cp -r /opt/stack /mnt/opt || fail

  # Move the log file to the new system
  mv /var/log/stack.log /mnt/var/log/stack.log
  chmod 766 /mnt/var/log/stack.log
}

log '\nStarting the bootstrap process...'

sync_clock &&
  set_mirrors &&
  sync_package_databases &&
  update_keyring &&
  install_kernels &&
  grant_permissions &&
  copy_installation_files

sleep 3
