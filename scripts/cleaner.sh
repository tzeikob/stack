#!/bin/bash

set -Eeo pipefail

source /opt/stack/scripts/utils.sh

# Deletes any remnants installation files from the new system.
remove_installation_files () {
  rm -rf /mnt/opt/stack

  if has_failed; then
    log WARN 'Unable to remove installation files'
    return 0
  fi

  log 'Installation files have been removed'
}

# Revokes any granted sudo permissions.
revoke_permissions () {
  # Revoke nopasswd permission
  local rule='%wheel ALL=(ALL:ALL) NOPASSWD: ALL'

  sed -i "s/^\(${rule}\)/# \1/" /mnt/etc/sudoers

  if has_failed; then
    log WARN 'Failed to revoke nopasswd permission'
    return 0
  fi

  if ! grep -q "^${rule}" /mnt/etc/sudoers; then
    log WARN 'Failed to revoke nopasswd permission'
    return 0
  fi

  log 'Permission nopasswd revoked from wheel group'
}

# Copies the installation log file to the new system.
copy_log_file () {
  cp /var/log/stack.log /mnt/var/log/stack.log ||
    log WARN 'Failed to copy log file to /mnt/var/log/stack.log'
}

log 'Cleaning up the new system...'

remove_installation_files &&
  revoke_permissions &&
  copy_log_file

sleep 3
