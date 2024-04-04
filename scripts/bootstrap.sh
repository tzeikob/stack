#!/bin/bash

set -Eeo pipefail

source /opt/stack/scripts/utils.sh

# Synchronizes the system clock to the current time.
sync_clock () {
  log INFO 'Updating the system clock...'

  local timezone=''
  timezone="$(get_setting 'timezone')" || fail 'Unable to read timezone setting'

  timedatectl set-timezone "${timezone}" 2>&1 ||
    fail 'Unable to set timezone'

  log INFO "Timezone has been set to ${timezone}"

  timedatectl set-ntp true 2>&1 ||
    fail 'Failed to enable NTP mode'

  log INFO 'NTP mode has been enabled'

  while timedatectl status 2>&1 | grep -q 'System clock synchronized: no'; do
    sleep 1
  done

  timedatectl status 2>&1 ||
    fail 'Failed to show system time status'

  log INFO 'System clock has been updated'
}

# Sets the pacman mirrors list.
set_mirrors () {
  log INFO 'Setting up package databases mirrors list...'

  local mirrors=''
  mirrors="$(get_setting 'mirrors' | jq -cer 'join(",")')" ||
    fail 'Unable to read mirrors setting'

  reflector --country "${mirrors}" \
    --age 48 --sort age --latest 40 --save /etc/pacman.d/mirrorlist 2>&1 ||
    fail 'Failed to fetch package databases mirrors'

  log INFO "Package databases mirrors set to ${mirrors}"
}

# Synchronizes package databases with the master.
sync_package_databases () {
  log INFO 'Starting to synchronize package databases...'

  local lock_file='/var/lib/pacman/db.lck'

  if file_exists "${lock_file}"; then
    log WARN 'Package databases seem to be locked'

    rm -f "${lock_file}" ||
      fail "Unable to remove the lock file ${lock_file}"

    log INFO "Lock file ${lock_file} has been removed"
  fi

  local keyserver='hkp://keyserver.ubuntu.com'

  echo "keyserver ${keyserver}" >> /etc/pacman.d/gnupg/gpg.conf ||
    fail 'Failed to add the GPG keyserver'

  log INFO "GPG keyserver has been set to ${keyserver}"

  sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf ||
    fail 'Failed to enable parallel downloads'

  pacman -Syy 2>&1 ||
    fail 'Failed to synchronize package databases'

  log INFO 'Package databases synchronized to the master'
}

# Updates the keyring package.
update_keyring () {
  log INFO 'Updating the archlinux keyring...'

  pacman -Sy --needed --noconfirm archlinux-keyring 2>&1 ||
    fail 'Failed to update keyring'

  log INFO 'Keyring has been updated successfully'
}

# Installs the linux kernel.
install_kernel () {
  log INFO 'Installing the linux kernel...'

  local kernel=''
  kernel="$(get_setting 'kernel')" || fail 'Unable to read kernel setting'

  local pckgs=''

  if equals "${kernel}" 'stable'; then
    pckgs='linux linux-headers'
  elif equals "${kernel}" 'lts'; then
    pckgs='linux-lts linux-lts-headers'
  fi

  if is_empty "${pckgs}"; then
    fail 'No linux kernel packages set for installation'
  fi

  pacstrap /mnt base ${pckgs} linux-firmware archlinux-keyring reflector rsync sudo jq 2>&1 ||
    fail 'Failed to pacstrap kernel and base packages'

  log INFO 'Linux kernel has been installed'
}

# Adds various extra sudoers rules.
add_sudoers_rules () {
  local proxy_rule='Defaults env_keep += "'
  proxy_rule+='http_proxy HTTP_PROXY '
  proxy_rule+='https_proxy HTTPS_PROXY '
  proxy_rule+='ftp_proxy FTP_PROXY '
  proxy_rule+='rsync_proxy RSYNC_PROXY '
  proxy_rule+='all_proxy ALL_PROXY '
  proxy_rule+='no_proxy NO_PROXY"'

  mkdir -p /mnt/etc/sudoers.d

  echo "${proxy_rule}" > /mnt/etc/sudoers.d/proxy_rules
  chmod 440 /mnt/etc/sudoers.d/proxy_rules

  log INFO 'Proxy rules have been added to sudoers'
}

# Grants the nopasswd permission to the wheel user group.
grant_permissions () {
  local rule='%wheel ALL=(ALL:ALL) NOPASSWD: ALL'

  sed -i "s/^# \(${rule}\)/\1/" /mnt/etc/sudoers ||
    fail 'Failed to grant nopasswd permission'

  if ! grep -q "^${rule}" /mnt/etc/sudoers; then
    fail 'Failed to grant nopasswd permission'
  fi

  log INFO 'Sudoer nopasswd permission has been granted'
}

# Copies the installation to the new system.
copy_installation_files () {
  log INFO 'Copying installation files...'

  cp -r /opt/stack /mnt/opt ||
    fail 'Unable to copy installation files to /mnt/opt'

  cp /etc/stack-release /mnt/etc/stack-release &&
    cat /usr/lib/os-release > /mnt/usr/lib/os-release &&
    rm -f /mnt/etc/arch-release ||
    fail 'Unable to copy the os release meta files'
  
  cp -r /etc/pacman.d/scripts /mnt/etc/pacman.d &&
    mkdir -p /mnt/etc/pacman.d/hooks &&
    cp /etc/pacman.d/hooks/90-fix-release.hook /mnt/etc/pacman.d/hooks ||
    fail 'Unable to copy fix release pacman hook'

  mkdir -p /mnt/var/log/stack ||
    fail 'Failed to create logs home under /mnt/var/log/stack'

  log INFO 'Installation files copied to /mnt/opt'
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

log INFO 'Script bootstrap.sh started'
log INFO 'Starting the bootstrap process...'

sync_clock &&
  set_mirrors &&
  sync_package_databases &&
  update_keyring &&
  install_kernel &&
  add_sudoers_rules &&
  grant_permissions &&
  copy_installation_files

log INFO 'Script bootstrap.sh has finished'

resolve && sleep 3
