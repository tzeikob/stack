#!/bin/bash

set -Eeo pipefail

source /opt/stack/scripts/utils.sh

# Revokes the nopasswd permission from the wheel user group.
revoke_permissions () {
  local rule='%wheel ALL=(ALL:ALL) NOPASSWD: ALL'

  sed -i "s/^\(${rule}\)/# \1/" /mnt/etc/sudoers || exit 1

  if ! grep -q "^# ${rule}" /mnt/etc/sudoers; then
    echo 'Failed to revoke nopasswd permission from wheel user group'
    exit 1
  fi

  echo 'Permission nopasswd revoked from wheel user group'
}

# Cleans up the new system of any remnants installation files.
clean_up () {
  echo 'Cleaning up the system...'

  rm -rf /mnt/opt/stack || exit 1

  echo 'Installation files have been removed'

  echo 'System clean up has been completed'
}

# Copies the installation log file to the new system.
copy_log_file () {
  local user_name=''
  user_name="$(get_setting 'user_name')" || exit 1

  echo "Log file saved to /home/${user_name}/stack.log"
  echo "Installation process completed at $(date)"

  cp /opt/stack/stack.log "/mnt/home/${user_name}" || exit 1
}

# Restarts for the first login into the system.
restart () {
  echo 'Rebooting the system in 15 secs...'

  sleep 15
  umount -R /mnt || echo 'Ignoring busy mount points'
  reboot
}

echo -e '\nBooting into the system for the first time...'

revoke_permissions &&
  clean_up &&
  copy_log_file &&
  restart
