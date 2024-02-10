#!/bin/bash

set -Eeo pipefail

source /opt/stack/scripts/utils.sh

LOG_FILE=/var/log/stack.log

# Executes the script with the given file name as the
# current user being in the archiso's shell session.
# Arguments:
#  file_name: the name of the script file
run () {
  local file_name="${1}"

  # Do not log while running the askme screens
  if equals "${file_name}" 'askme'; then
    bash /opt/stack/scripts/askme.sh || exit 1
  else
    log "Script ${file_name}.sh started" |
      tee -a "${LOG_FILE}"

    bash "/opt/stack/scripts/${file_name}.sh" 2>&1 |
      tee -a "${LOG_FILE}" | grep -E '^(INFO|WARN|EROR) '

    if has_failed; then
      log EROR "Script ${file_name}.sh has failed" |
        tee -a "${LOG_FILE}"

      exit 1
    fi

    log "Script ${file_name}.sh has finished" |
      tee -a "${LOG_FILE}"
  fi
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
  if match "${file_name}" '^(desktop|stack|tools)$'; then
    user_name="$(get_setting 'user_name')"

    if has_failed; then
      log EROR 'Unable to get the user name setting' |
        tee -a "${LOG_FILE}"

      exit 1
    fi
  fi

  log "Script ${file_name}.sh started" |
    tee -a "${LOG_FILE}"

  arch-chroot /mnt runuser -u "${user_name}" -- "${script_file}" 2>&1 |
    tee -a "${LOG_FILE}" | grep -E '^(INFO|WARN|EROR) '
  
  if has_failed; then
    log EROR "Script ${file_name}.sh has failed" |
      tee -a "${LOG_FILE}"

    exit 1
  fi

  log "Script ${file_name}.sh has finished" |
    tee -a "${LOG_FILE}"
}

# Restarts the system.
restart () {
  log 'Rebooting the system in 15 secs...'

  sleep 15
  umount -R /mnt || log WARN 'Ignoring busy mount points'
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

confirm 'Do you want to proceed?'

if is_not_given "${REPLY}" || is_no "${REPLY}"; then
  echo -e 'Sure, maybe next time!'
  exit 0
fi

run askme &&
  run detection &&
  run diskpart &&
  run bootstrap &&
  install system &&
  install desktop &&
  install stack &&
  install tools &&
  run cleaner &&
  restart
