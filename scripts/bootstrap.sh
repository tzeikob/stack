#!/bin/bash

set -Eeo pipefail

source /opt/stack/scripts/utils.sh

# Synchronizes the system clock to the current time.
sync_clock () {
  echo -e 'Updating the system clock...'

  local timezone=''
  timezone="$(get_setting 'timezone')" || fail

  timedatectl set-timezone "${timezone}" || fail 'Unable to set timezone'

  echo -e "Timezone has been set to ${timezone}"

  timedatectl set-ntp true || fail 'Failed to enable NTP mode'

  echo -e 'NTP mode has been enabled'

  while timedatectl status | grep -q 'System clock synchronized: no'; do
    sleep 1
  done

  timedatectl status || fail 'Failed to show system time status'

  echo -e 'System clock has been updated'
}

# Sets the pacman mirrors list.
set_mirrors () {
  echo -e 'Setting up package databases mirrors list...'

  local mirrors=''
  mirrors="$(get_setting 'mirrors' | jq -cer 'join(",")')" || fail

  reflector --country "${mirrors}" --age 48 --sort age --latest 40 \
    --save /etc/pacman.d/mirrorlist || fail 'Failed to fetch package databases mirrors'

  echo -e "Package databases mirrors set to ${mirrors}"
}

# Synchronizes package databases with the master.
sync_package_databases () {
  echo -e 'Starting to synchronize package databases...'

  local lock_file='/var/lib/pacman/db.lck'

  if file_exists "${lock_file}"; then
    echo -e 'Package databases seem to be locked'

    rm -f "${lock_file}" || fail "Unable to remove the lock file ${lock_file}"

    echo -e "Lock file ${lock_file} has been removed"
  fi

  local keyserver='hkp://keyserver.ubuntu.com'

  echo "keyserver ${keyserver}" >> /etc/pacman.d/gnupg/gpg.conf || fail 'Failed to add the GPG keyserver'

  echo -e "GPG keyserver has been set to ${keyserver}"

  sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf || fail 'Failed to enable parallel downloads'

  pacman -Syy || fail 'Failed to synchronize pacjage databases'

  echo -e 'Package databases synchronized to the master'
}

# Updates the keyring package.
update_keyring () {
  echo -e 'Updating the archlinux keyring...'

  pacman -Sy --noconfirm archlinux-keyring || fail 'Failed to update keyring'

  echo -e 'Keyring has been updated successfully'
}

# Installs the linux kernels.
install_kernels () {
  echo -e 'Installing the linux kernels...'

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

  pacstrap /mnt base ${pckgs} linux-firmware archlinux-keyring \
    reflector rsync sudo jq || fail 'Failed to pacstrap kernels and base packages'

  echo -e 'Linux kernels have been installed'
}

# Grants the nopasswd permission to the wheel user group.
grant_permissions () {
  local rule='%wheel ALL=(ALL:ALL) NOPASSWD: ALL'

  sed -i "s/^# \(${rule}\)/\1/" /mnt/etc/sudoers ||
    fail 'Failed to grant nopasswd permission'

  if ! grep -q "^${rule}" /mnt/etc/sudoers; then
    fail 'Failed to grant nopasswd permission'
  fi

  echo -e 'Sudoer nopasswd permission has been granted'
}

# Copies the installation to the new system.
copy_installation_files () {
  echo -e 'Copying installation files...'

  cp -r /opt/stack /mnt/opt || fail 'Unable to copy installation file to /mnt'

  echo -e 'Installation files copied to /mnt'
}

echo -e 'Starting the bootstrap process...'

sync_clock &&
  set_mirrors &&
  sync_package_databases &&
  update_keyring &&
  install_kernels &&
  grant_permissions &&
  copy_installation_files

sleep 3
