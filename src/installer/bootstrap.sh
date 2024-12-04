#!/bin/bash

set -Eeo pipefail

source src/commons/error.sh
source src/commons/logger.sh
source src/commons/validators.sh
source src/commons/math.sh

SETTINGS_FILE=./settings.json

# Synchronizes the system clock to the current time.
sync_clock () {
  log INFO 'Updating the system clock...'

  timedatectl status | jc --parser timedatectl > /tmp/clock.bk ||
    abort ERROR 'Failed to backup the clock settings.'
  
  log INFO 'Clock settings backed up to /tmp/clock.bk.'

  local timezone=''
  timezone="$(jq -cer '.timezone' "${SETTINGS_FILE}")" ||
    abort ERROR 'Unable to read timezone setting.'

  timedatectl set-timezone "${timezone}" 2>&1 ||
    abort ERROR 'Unable to set timezone.'

  log INFO "Timezone has been set to ${timezone}."

  timedatectl set-ntp true 2>&1 ||
    abort ERROR 'Failed to enable NTP mode.'

  log INFO 'NTP mode has been enabled.'

  while timedatectl status 2>&1 | grep -q 'System clock synchronized: no'; do
    sleep 1
  done

  timedatectl status 2>&1 ||
    abort ERROR 'Failed to show system time status.'

  log INFO 'System clock has been updated.'
}

# Sets the pacman mirrors list.
set_mirrors () {
  log INFO 'Setting up package databases mirrors list...'

  cp /etc/pacman.d/mirrorlist /tmp/mirrorlist.bk ||
    abort ERROR 'Failed to backup the pacman mirror list.'
  
  log INFO 'Pacman mirror list backed up to /tmp/mirrorlist.bk.'

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

  local util_pkgs='reflector rsync sudo jq libqalculate'

  pacstrap /mnt base ${linux_pkgs} ${util_pkgs} 2>&1 ||
    abort ERROR 'Failed to pacstrap kernel and base packages.'

  log INFO 'Linux kernel has been installed.'
}

# Copies the installation files to new system.
copy_installation_files () {
  log INFO 'Copying installation files to new system...'

  local target='/mnt/stack'

  rm -rf "${target}" &&
    rsync -av /stack/ "${target}" --exclude .git --exclude .gitignore ||
    abort ERROR 'Unable to copy installation files.'

  mkdir -p /mnt/var/log/stack/installer

  log INFO 'Installation files have been copied.'
}

# Restores the clock timezone and NTP service.
restore_clock () {
  log INFO 'Restoring clock settings...'

  local timezone=''
  timezone="$(jq -cer '.time_zone|split(" ")[0]' /tmp/clock.bk)"

  if has_not_failed; then
    timedatectl set-timezone "${timezone}" 2>&1 &&
      log INFO "Timezone restored back to ${timezone}." ||
      log WARN "Unable to restore clock timezone to ${timezone}."
  else
    log WARN 'Unable to read timezone from clock backup file.'
  fi
  
  local ntp_service=''
  ntp_service="$(jq -cer '.ntp_service | . == "active"' /tmp/clock.bk)"

  if has_not_failed; then
    timedatectl set-ntp "${ntp_service}" 2>&1 &&
      log INFO "NTP service restored back to ${ntp_service}." ||
      log WARN "Unable to restore NTP service to ${ntp_service}."
  else
    log WARN 'Unable to read NTP service from clock backup file.'
  fi
}

# Restores the pacman mirror list.
restore_mirrors () {
  log INFO 'Restoring pacman mirror list...'

  mv /tmp/mirrorlist.bk /etc/pacman.d/mirrorlist &&
    log INFO 'Pacman mirror list has been restored.' ||
    log WARN 'Unable to restore the pacman mirror list.'
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

  local log_file='/var/log/stack/installer/bootstrap.log'

  local lines=0
  lines=$(cat "${log_file}" | wc -l)

  local fake_lines=0
  fake_lines=$(calc "${total} - ${lines}")

  seq ${fake_lines} | xargs -I -- echo '~'
}

log INFO 'Script bootstrap.sh started.'
log INFO 'Starting the bootstrap process...'

sync_clock &&
  set_mirrors &&
  sync_package_databases &&
  update_keyring &&
  install_kernel &&
  copy_installation_files &&
  restore_clock &&
  restore_mirrors

log INFO 'Script bootstrap.sh has finished.'

resolve 660 && sleep 2
