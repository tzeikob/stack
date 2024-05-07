#!/bin/bash

set -Eeo pipefail

source /opt/stack/commons/utils.sh
source /opt/stack/commons/logger.sh

# Deletes any remnants installation files from the new system.
remove_installation_files () {
  rm -rf /mnt/opt/stack/installer

  if has_failed; then
    log WARN 'Unable to remove installation files.'
    return 0
  fi

  log INFO 'Installation files have been removed.'
}

# Revokes any granted sudo permissions.
revoke_permissions () {
  # Revoke nopasswd permission
  local rule='%wheel ALL=(ALL:ALL) NOPASSWD: ALL'

  sed -i "s/^\(${rule}\)/# \1/" /mnt/etc/sudoers

  if has_failed; then
    log WARN 'Failed to revoke nopasswd permission.'
    return 0
  fi

  if ! grep -q "^# ${rule}" /mnt/etc/sudoers; then
    log WARN 'Failed to revoke nopasswd permission.'
    return 0
  fi

  log INFO 'Permission nopasswd revoked from wheel group.'
}

log INFO 'Script cleaner.sh started.'
log INFO 'Cleaning up the new system...'

remove_installation_files &&
  revoke_permissions

log INFO 'Script cleaner.sh has finished.'

resolve cleaner 12 && sleep 2
