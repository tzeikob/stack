#!/bin/bash

set -Eeo pipefail

source /opt/stack/scripts/utils.sh

# Executes the script with the given file name as the
# current user being in the archiso's shell session.
# Arguments:
#  file_name: the name of the script file
run () {
  local file_name="${1}"

  bash "/opt/stack/scripts/${file_name}.sh"
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

  arch-chroot /mnt runuser -u "${user_name}" -- "${script_file}"
}

# Cleans up the new system and revokes permissions.
clean_up () {
  log -t console 'Cleaning up the system...'

  rm -rf /mnt/opt/stack

  # Revoke nopasswd permissions
  local rule='%wheel ALL=(ALL:ALL) NOPASSWD: ALL'
  sed -i "s/^\(${rule}\)/# \1/" /mnt/etc/sudoers
}

# Restarts the system.
restart () {
  log -t console 'Rebooting the system in 15 secs...'

  sleep 15
  umount -R /mnt || log -t console 'Ignoring busy mount points'
  reboot
}

clear

cat << EOF
░░░█▀▀░▀█▀░█▀█░█▀▀░█░█░░░
░░░▀▀█░░█░░█▀█░█░░░█▀▄░░░
░░░▀▀▀░░▀░░▀░▀░▀▀▀░▀░▀░░░
EOF

log -t console '\nWelcome to StackOS Installer, v1.0.0.alpha.'
log -t console 'Base your development stack on archlinux!\n'

log -t console "Let's start by picking some installation settings..."
confirm 'Do you want to proceed?' || fail

if is_not_given "${REPLY}" || is_no "${REPLY}"; then
  fail 'Installation has been canceled'
fi

run askme &&
  run diskpart &&
  run bootstrap &&
  install system &&
  install desktop &&
  install stack &&
  install tools &&
  clean_up &&
  restart
