#!/bin/bash

set -Eeo pipefail

source /opt/stack/scripts/utils.sh

# Synchronizes the system clock to the current time.
sync_clock () {
  log 'Updating the system clock...'

  local timezone=''
  timezone="$(get_setting 'timezone')" || fail

  timedatectl set-timezone "${timezone}" 2>&1 ||
    fail 'Unable to set timezone'

  log "Timezone has been set to ${timezone}"

  timedatectl set-ntp true 2>&1 ||
    fail 'Failed to enable NTP mode'

  log 'NTP mode has been enabled'

  while timedatectl status 2>&1 | grep -q 'System clock synchronized: no'; do
    sleep 1
  done

  timedatectl status 2>&1 ||
    fail 'Failed to show system time status'

  log 'System clock has been updated'
}

# Sets the pacman mirrors list.
set_mirrors () {
  log 'Setting up package databases mirrors list...'

  local mirrors=''
  mirrors="$(get_setting 'mirrors' | jq -cer 'join(",")')" || fail

  reflector --country "${mirrors}" \
    --age 48 --sort age --latest 40 --save /etc/pacman.d/mirrorlist 2>&1 ||
    fail 'Failed to fetch package databases mirrors'

  log "Package databases mirrors set to ${mirrors}"
}

# Synchronizes package databases with the master.
sync_package_databases () {
  log 'Starting to synchronize package databases...'

  local lock_file='/var/lib/pacman/db.lck'

  if file_exists "${lock_file}"; then
    log WARN 'Package databases seem to be locked'

    rm -f "${lock_file}" ||
      fail "Unable to remove the lock file ${lock_file}"

    log "Lock file ${lock_file} has been removed"
  fi

  local keyserver='hkp://keyserver.ubuntu.com'

  echo "keyserver ${keyserver}" >> /etc/pacman.d/gnupg/gpg.conf ||
    fail 'Failed to add the GPG keyserver'

  log "GPG keyserver has been set to ${keyserver}"

  sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf ||
    fail 'Failed to enable parallel downloads'

  pacman -Syy 2>&1 ||
    fail 'Failed to synchronize pacjage databases'

  log 'Package databases synchronized to the master'
}

# Updates the keyring package.
update_keyring () {
  log 'Updating the archlinux keyring...'

  pacman -Sy --needed --noconfirm archlinux-keyring 2>&1 ||
    fail 'Failed to update keyring'

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

  pacstrap /mnt base ${pckgs} linux-firmware archlinux-keyring reflector rsync sudo jq 2>&1 ||
    fail 'Failed to pacstrap kernels and base packages'

  log 'Linux kernels have been installed'
}

# Grants the nopasswd permission to the wheel user group.
grant_permissions () {
  local rule='%wheel ALL=(ALL:ALL) NOPASSWD: ALL'

  sed -i "s/^# \(${rule}\)/\1/" /mnt/etc/sudoers ||
    fail 'Failed to grant nopasswd permission'

  if ! grep -q "^${rule}" /mnt/etc/sudoers; then
    fail 'Failed to grant nopasswd permission'
  fi

  log 'Sudoer nopasswd permission has been granted'
}

# Copies the installation to the new system.
copy_installation_files () {
  log 'Copying installation files...'

  cp -r /opt/stack /mnt/opt ||
    fail 'Unable to copy installation file to /mnt/opt'
  
  mkdir -p /mnt/var/log/stack ||
    fail 'Failed to create logs home under /mnt/var/log/stack'

  log 'Installation files copied to /mnt/opt'
}

# Resolves the installaction script by addressing
# some extra post execution tasks.
resolve () {
  # Read the current progress as the number of log lines
  local lines=0
  lines=$(cat /var/log/stack/bootstrap.log | wc -l) ||
    fail 'Unable to read the current log lines'

  local total=660

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

log 'Script bootstrap.sh started'
log 'Starting the bootstrap process...'

sync_clock &&
  set_mirrors &&
  sync_package_databases &&
  update_keyring &&
  install_kernels &&
  grant_permissions &&
  copy_installation_files

log 'Script bootstrap.sh has finished'

resolve && sleep 3
