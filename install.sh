#!/bin/bash

set -Eeo pipefail

source /opt/stack/scripts/utils.sh

# Executes the script with the given file name as the
# current user being in the archiso's shell session.
# Arguments:
#  file_name: the name of the script file
run () {
  local file_name="${1}"

  echo -e "Running the ${file_name}..."

  bash "/opt/stack/scripts/${file_name}.sh" \
    2>&1 >> /var/log/stack.log
  
  echo "Script ${file_name} has been completed"
}

# Changes to the shell session of the mounted installation disk
# as the root or sudoer user and executes the script with the given
# file name which corresponds to the part of the system that is
# about to be installed.
# Arguments:
#  file_name: the name of the script file
install () {
  local file_name="${1}"

  local script_file="/opt/stack/scripts/${file_name}.sh"

  local user_name='root'

  # Impersonate the sudoer user on desktop, stack and tools installation
  if match "${1}" '^(desktop|stack|tools)$'; then
    user_name="$(get_setting 'user_name')" || fail
  fi

  echo -e "Installing the ${file_name}..."

  arch-chroot /mnt runuser -u "${user_name}" -- "${script_file}" \
    2>&1 >> /var/log/stack.log
  
  echo -e "The ${file_name} installation has been completed"
}

# Cleans up the new system and revokes permissions.
clean () {
  echo -e 'Cleaning up the new system...'

  rm -rf /mnt/opt/stack || fail 'Unable to remove installation files'

  echo -e 'Installation files have been removed'

  # Revoke nopasswd permission
  local rule='%wheel ALL=(ALL:ALL) NOPASSWD: ALL'

  sed -i "s/^\(${rule}\)/# \1/" /mnt/etc/sudoers ||
    fail 'Failed to revoke nopasswd permission'

  if ! grep -q "^${rule}" /mnt/etc/sudoers; then
    fail 'Failed to revoke nopasswd permission'
  fi

  echo -e 'Sudoer nopasswd permission has been revoked'

  cp /var/log/stack.log /mnt/var/log/stack.log

  echo -e 'Log file copied to /var/log/stack.log'
}

# Restarts the system.
restart () {
  echo -e 'Rebooting the system in 15 secs...'

  sleep 15
  umount -R /mnt || echo -e 'Ignoring busy mount points'
  reboot
}

clear

cat << EOF
░░░█▀▀░▀█▀░█▀█░█▀▀░█░█░░░
░░░▀▀█░░█░░█▀█░█░░░█▀▄░░░
░░░▀▀▀░░▀░░▀░▀░▀▀▀░▀░▀░░░
EOF

echo -e '\nWelcome to StackOS Installer, v1.0.0.alpha.'
echo -e 'Base your development stack on archlinux!'

confirm 'Do you want to proceed?' || fail

if is_not_given "${REPLY}" || is_no "${REPLY}"; then
  echo -e 'Sure, maybe next time!'
  exit 0
fi

run askme &&
  run diskpart &&
  run bootstrap &&
  install system &&
  install desktop &&
  install stack &&
  install tools &&
  clean &&
  restart
