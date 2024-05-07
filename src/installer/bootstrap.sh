#!/bin/bash

set -Eeo pipefail

source /opt/stack/commons/utils.sh
source /opt/stack/commons/logger.sh
source /opt/stack/commons/validators.sh

# Synchronizes the system clock to the current time.
sync_clock () {
  log INFO 'Updating the system clock...'

  local timezone=''
  timezone="$(get_setting 'timezone')" || abort ERROR 'Unable to read timezone setting.'

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

  local mirrors=''
  mirrors="$(get_setting 'mirrors' | jq -cer 'join(",")')" ||
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

  local keyserver='hkp://keyserver.ubuntu.com'

  echo "keyserver ${keyserver}" >> /etc/pacman.d/gnupg/gpg.conf ||
    abort ERROR 'Failed to add the GPG keyserver.'

  log INFO "GPG keyserver has been set to ${keyserver}."

  sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf ||
    abort ERROR 'Failed to enable parallel downloads.'

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
  kernel="$(get_setting 'kernel')" || abort ERROR 'Unable to read kernel setting.'

  local pckgs=''

  if equals "${kernel}" 'stable'; then
    pckgs='linux linux-headers'
  elif equals "${kernel}" 'lts'; then
    pckgs='linux-lts linux-lts-headers'
  fi

  if is_empty "${pckgs}"; then
    abort ERROR 'No linux kernel packages set for installation.'
  fi

  pacstrap /mnt base ${pckgs} linux-firmware archlinux-keyring reflector rsync sudo jq 2>&1 ||
    abort ERROR 'Failed to pacstrap kernel and base packages.'

  log INFO 'Linux kernel has been installed.'
}

# Installs the common tools to share common utilities.
install_commons () {
  log INFO 'Installing the common tools...'

  mkdir -p /mnt/opt/stack &&
    cp -r /opt/stack/commons /mnt/opt/stack ||
    abort ERROR 'Failed to install common tools.'
  
  log INFO 'Common tools have been installed.'
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

  log INFO 'Proxy rules have been added to sudoers.'
}

# Grants the nopasswd permission to the wheel user group.
grant_permissions () {
  local rule='%wheel ALL=(ALL:ALL) NOPASSWD: ALL'

  sed -i "s/^# \(${rule}\)/\1/" /mnt/etc/sudoers ||
    abort ERROR 'Failed to grant nopasswd permission.'

  if ! grep -q "^${rule}" /mnt/etc/sudoers; then
    abort ERROR 'Failed to grant nopasswd permission.'
  fi

  log INFO 'Sudoer nopasswd permission has been granted.'
}

# Copies the release hook to the new system.
copy_release_hook () {
  cp /etc/stack-release /mnt/etc/stack-release &&
    cat /usr/lib/os-release > /mnt/usr/lib/os-release &&
    rm -f /mnt/etc/arch-release ||
    abort ERROR 'Unable to copy the os release meta files.'
  
  cp -r /etc/pacman.d/scripts /mnt/etc/pacman.d &&
    mkdir -p /mnt/etc/pacman.d/hooks &&
    cp /etc/pacman.d/hooks/90-fix-release.hook /mnt/etc/pacman.d/hooks ||
    abort ERROR 'Unable to copy fix release pacman hook.'
  
  log INFO 'Release hook has been copied.'
}

# Copies the installation files to the new system.
copy_installer () {
  log INFO 'Copying installer files...'

  mkdir -p /mnt/opt/stack &&
    cp -r /opt/stack/installer /mnt/opt/stack ||
    abort ERROR 'Unable to copy installer files.'

  log INFO 'Installer files have been copied.'
}

# Copies the log files.
copy_logs_files () {
  mkdir -p /mnt/var/log/stack ||
    abort ERROR 'Failed to create logs home under /mnt/var/log/stack.'
  
  log INFO 'Log files have been copied.'
}

log INFO 'Script bootstrap.sh started.'
log INFO 'Starting the bootstrap process...'

sync_clock &&
  set_mirrors &&
  sync_package_databases &&
  update_keyring &&
  install_kernel &&
  install_commons &&
  add_sudoers_rules &&
  grant_permissions &&
  copy_release_hook &&
  copy_installer &&
  copy_logs_files

log INFO 'Script bootstrap.sh has finished.'

resolve bootstrap 660 && sleep 2
