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

  if ! grep -q "^# ${rule}" /mnt/etc/sudoers; then
    log WARN 'Failed to revoke nopasswd permission'
    return 0
  fi

  log 'Permission nopasswd revoked from wheel group'
}

# Appends all log files into one installation log file and
# saves it to the new system.
copy_log_file () {
  cat /var/log/stack/detection.log \
    /var/log/stack/diskpart.log \
    /var/log/stack/bootstrap.log > /mnt/var/log/stack.log ||
    log WARN 'Failed to append log files to /mnt/var/log/stack.log'


  cat /mnt/var/log/stack/system.log \
    /mnt/var/log/stack/desktop.log \
    /mnt/var/log/stack/stack.log \
    /mnt/var/log/stack/tools.log \
    /var/log/stack/cleaner.log >> /mnt/var/log/stack.log ||
    log WARN 'Failed to append log files to /mnt/var/log/stack.log'
  
  rm -rf /var/log/stack ||
    log WARN 'Failed to remove /var/log/stack folder'

  rm -rf /mnt/var/log/stack ||
    log WARN 'Failed to remove /mnt/var/log/stack folder'
}

# Resolves the installaction script by addressing
# some extra post execution tasks.
resolve () {
  # Read the current progress as the number of log lines
  local lines=0
  lines=$(cat /var/log/stack/cleaner.log | wc -l) ||
    fail 'Unable to read the current log lines'

  local total=12

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

log 'Script cleaner.sh started'
log 'Cleaning up the new system...'

remove_installation_files &&
  revoke_permissions &&
  copy_log_file

log 'Script cleaner.sh has finished'

resolve && sleep 3
