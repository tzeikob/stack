#!/bin/bash

set -Eeo pipefail

source /opt/stack/scripts/utils.sh

# Executes the script with the given file name as the
# current user being in the archiso's shell session.
# Arguments:
#  file_name: the name of the script file
run () {
  local file_name="${1}"

  bash "/opt/stack/scripts/${file_name}.sh" > >(tee -a /opt/stack/stack.log) 2>&1
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
    user_name="$(get_setting 'user_name')" || abort
  fi

  arch-chroot /mnt runuser -u "${user_name}" -- "${script_file}" > >(tee -a /opt/stack/stack.log) 2>&1
}

# Exit the installation process immediately.
abort () {
  echo 'Process exiting with status code 1...'
  exit 1
}

clear

cat << EOF
░░░█▀▀░▀█▀░█▀█░█▀▀░█░█░░░
░░░▀▀█░░█░░█▀█░█░░░█▀▄░░░
░░░▀▀▀░░▀░░▀░▀░▀▀▀░▀░▀░░░
EOF

echo -e '\nWelcome to Stack Installer, v1.0.0.alpha.'
echo -e 'Base your development workflow on archlinux!\n'

echo "Let's start by picking some installation settings..."
confirm 'Do you want to proceed?' || abort

if is_not_given "${REPLY}" || is_no "${REPLY}"; then
  echo 'Installation process canceled'
  abort
fi

echo

run askme &&
  run diskpart &&
  run bootstrap &&
  install system &&
  install desktop &&
  install stack &&
  install tools &&
  run reboot || abort
