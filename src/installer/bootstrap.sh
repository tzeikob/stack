#!/bin/bash

set -Eeo pipefail

source src/commons/error.sh
source src/commons/logger.sh
source src/commons/validators.sh
source src/commons/math.sh

SETTINGS_FILE=./settings.json

# Sets the pacman mirrors list.
set_mirrors () {
  log INFO 'Setting up package databases mirrors list...'

  cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bk ||
    abort ERROR 'Failed to backup the pacman mirror list.'
  
  log INFO 'Pacman mirror list backed up to /etc/pacman.d/mirrorlist.bk.'

  local mirrors=''
  mirrors="$(jq -cer '.mirrors|join(",")' "${SETTINGS_FILE}")" ||
    abort ERROR 'Unable to read mirrors setting.'

  reflector --country "${mirrors}" \
    --age 48 --sort age --latest 40 --save /etc/pacman.d/mirrorlist 2>&1 ||
    abort ERROR 'Failed to fetch package databases mirrors.'

  log INFO "Package databases mirrors set to ${mirrors}."
}

# Synchronizes package databases with the master.
sync_package_databases () {
  log INFO 'Starting to synchronize package databases...'

  local lock_file='/var/lib/pacman/db.lck'

  if file_exists "${lock_file}"; then
    log WARN 'Package databases seem to be locked.'

    rm -f "${lock_file}" ||
      abort ERROR "Unable to remove the lock file ${lock_file}."

    log INFO "Lock file ${lock_file} has been removed."
  fi

  if ! grep -qe '^keyserver ' /etc/pacman.d/gnupg/gpg.conf; then
    local keyserver='hkp://keyserver.ubuntu.com'

    echo "keyserver ${keyserver}" >> /etc/pacman.d/gnupg/gpg.conf ||
      abort ERROR 'Failed to add the GPG keyserver.'

    log INFO "GPG keyserver ${keyserver} has been added."
  fi

  pacman -Syy 2>&1 ||
    abort ERROR 'Failed to synchronize package databases.'

  log INFO 'Package databases synchronized to the master.'
}

# Updates the keyring package.
update_keyring () {
  log INFO 'Updating the archlinux keyring...'

  pacman -Sy --needed --noconfirm archlinux-keyring 2>&1 ||
    abort ERROR 'Failed to update keyring.'

  log INFO 'Keyring has been updated successfully.'
}

# Installs the linux kernel.
install_kernel () {
  log INFO 'Installing the linux kernel...'

  # Copy mandatory pacman scripts for pacstrap
  rsync -av /etc/pacman.d/scripts /mnt/etc/pacman.d ||
    abort ERROR 'Unable to copy pacman scripts.'

  local kernel=''
  kernel="$(jq -cer '.kernel' "${SETTINGS_FILE}")" ||
    abort ERROR 'Unable to read kernel setting.'

  local linux_pkgs=''

  if equals "${kernel}" 'stable'; then
    linux_pkgs='linux linux-headers'
  elif equals "${kernel}" 'lts'; then
    linux_pkgs='linux-lts linux-lts-headers'
  fi

  if is_empty "${linux_pkgs}"; then
    abort ERROR 'No linux kernel packages set for installation.'
  fi

  linux_pkgs+=' linux-firmware'

  local util_pkgs='git reflector rsync sudo jq libqalculate'

  pacstrap /mnt base ${linux_pkgs} ${util_pkgs} 2>&1 ||
    abort ERROR 'Failed to pacstrap kernel and base packages.'

  log INFO 'Linux kernel has been installed.'
}

# Restores the pacman mirror list.
restore_mirrors () {
  log INFO 'Restoring pacman mirror list...'

  mv /etc/pacman.d/mirrorlist.bk /etc/pacman.d/mirrorlist &&
    log INFO 'Pacman mirror list has been restored.' ||
    log WARN 'Unable to restore the pacman mirror list.'
}

log INFO 'Script bootstrap.sh started.'
log INFO 'Starting the bootstrap process...'

set_mirrors &&
  sync_package_databases &&
  update_keyring &&
  install_kernel &&
  restore_mirrors ||
  abort

log INFO 'Script bootstrap.sh has finished.'
