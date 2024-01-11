#!/bin/bash

set -Eeo pipefail

source /opt/stack/scripts/utils.sh

# Synchronizes the system clock to the current time.
sync_clock () {
  echo 'Updating the system clock...'

  local timezone=''
  timezone="$(get_setting 'timezone')" || exit 1

  timedatectl set-timezone "${timezone}" || exit 1

  echo "Timezone has been set to ${timezone}"

  timedatectl set-ntp true || exit 1

  echo 'NTP mode has been enabled'

  while timedatectl status | grep -q 'System clock synchronized: no'; do
    sleep 1
  done

  timedatectl status

  echo 'System clock has been updated'
}

# Sets the pacman mirrors list.
set_mirrors () {
  echo 'Setting up pacman mirrors list...'

  local mirrors=''
  mirrors="$(get_setting 'mirrors' | jq -cer 'join(",")')" || exit 1

  reflector --country "${mirrors}" --age 48 --sort age --latest 40 \
    --save /etc/pacman.d/mirrorlist

  if has_failed; then
    echo "Reflector failed to retrieve ${mirrors} mirrors"
    echo 'Falling back to default mirrors'
  else
    echo "Pacman mirrors list set to ${mirrors}"
  fi
}

# Synchronizes package databases with the master.
sync_package_databases () {
  echo 'Starting to synchronize package databases...'

  local lock_file='/var/lib/pacman/db.lck'

  if file_exists "${lock_file}"; then
    echo 'Package databases seem to be locked'

    rm -f "${lock_file}" || exit 1

    echo "Lock file ${lock_file} has been removed"
  fi

  local keyserver='hkp://keyserver.ubuntu.com'

  echo "keyserver ${keyserver}" >> /etc/pacman.d/gnupg/gpg.conf

  echo "GPG keyserver has been set to ${keyserver}"

  sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

  pacman -Syy || exit 1

  echo 'Package databases synchronized with the master'
}

# Updates the keyring package.
update_keyring () {
  echo 'Updating keyring package...'

  pacman -Sy --noconfirm archlinux-keyring || exit 1

  echo 'Keyring has been updated successfully'
}

# Installs the linux kernels.
install_kernels () {
  echo 'Installing the linux kernels...'

  local kernels=''
  kernels="$(get_setting 'kernels' | jq -cer 'join(" ")')" || exit 1

  local pckgs=''

  if match "${kernels}" 'stable'; then
    pckgs='linux linux-headers'
  fi

  if match "${kernels}" 'lts'; then
    pckgs+=' linux-lts linux-lts-headers'
  fi

  if is_empty "${pckgs}"; then
    echo 'No linux kernel packages set for installation'
    exit 1
  fi

  pacstrap /mnt base ${pckgs} linux-firmware archlinux-keyring reflector rsync sudo jq || exit 1

  echo 'Linux kernels have been installed'
}

# Grants the nopasswd permission to the wheel user group.
grant_permissions () {
  local rule='%wheel ALL=(ALL:ALL) NOPASSWD: ALL'

  sed -i "s/^# \(${rule}\)/\1/" /mnt/etc/sudoers || exit 1

  if ! grep -q "^${rule}" /mnt/etc/sudoers; then
    echo 'Failed to grant nopasswd permission to wheel user group'
    exit 1
  fi

  echo 'Permission nopasswd granted to wheel user group'
}

# Copies the stack files to the installation disk.
copy_installation_files () {
  echo 'Start copying installation files...'

  cp -r /opt/stack /mnt/opt || exit 1

  echo 'Installation files moved to /mnt/opt/stack'
}

echo -e '\nStarting the bootstrap process...'

sync_clock &&
  set_mirrors &&
  sync_package_databases &&
  update_keyring &&
  install_kernels &&
  grant_permissions &&
  copy_installation_files

echo -e '\nBootstrap process has been completed successfully'
echo 'Moving to the system installation process...'
sleep 5
