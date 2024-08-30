#!/bin/bash

set -Eeo pipefail

source src/commons/error.sh
source src/commons/logger.sh
source src/commons/math.sh

# Deletes any remnants installation files from the new system.
remove_installation_files () {
  rm -rf /mnt/stack

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

# Prints dummy log lines to fake tqdm progress bar, when a
# task gives less lines than it is expected to print and so
# it resolves with fake lines to emulate completion.
# Arguments:
#  total: the log lines the task is expected to print
# Outputs:
#  Fake dummy log lines.
resolve () {
  local total="${1}"

  local lines=0
  lines=$(cat /var/log/stack/cleaner.log | wc -l)

  local fake_lines=0
  fake_lines=$(calc "${total} - ${lines}")

  seq ${fake_lines} | xargs -I -- log '~'
}

log INFO 'Script cleaner.sh started.'
log INFO 'Cleaning up the new system...'

remove_installation_files &&
  revoke_permissions

log INFO 'Script cleaner.sh has finished.'

resolve 12 && sleep 2
