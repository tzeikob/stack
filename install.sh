#!/bin/bash

set -Eeo pipefail

BAR_FORMAT='{desc:10} {percentage:3.0f}%|{bar}| {elapsed:8}'

source /opt/stack/scripts/utils.sh

# Initializes the installer.
init () {
  # Reset possibly existing log files
  rm -rf /var/log/stack
  mkdir -p /var/log/stack
  
  # Initialize the settings file
  init_settings
}

# Report any collected installation settings.
report () {
  local log_file="/var/log/stack/report.log"

  local query=''
  query='.user_password = "***" | .root_password = "***"'

  local settings=''
  settings="$(get_settings | jq "${query}")"

  if has_failed; then
    log ERROR 'Unable to read settings' >> "${log_file}"
    log 'A fatal error occurred, process exited!'
    exit 1
  fi

  log '\nInstallation properties have been set to:' > "${log_file}"
  log "${settings}\n" >> "${log_file}"
}

# Executes the script with the given file name as the
# current user being in the archiso's shell session.
# Arguments:
#  file_name: the name of the script file
run () {
  local file_name="${1}"

  # Do not log while running the askme screens
  if equals "${file_name}" 'askme'; then
    bash /opt/stack/scripts/askme.sh || exit 1
    
    echo
    return 0
  fi

  local total=0

  case "${file_name}" in
    'detection') total=15;;
    'diskpart') total=90;;
    'bootstrap') total=660;;
    'cleaner') total=12;;
  esac
  
  local log_file="/var/log/stack/${file_name}.log"

  bash "/opt/stack/scripts/${file_name}.sh" 2>&1 |
    tee -a "${log_file}" 2>&1 |
    tqdm --desc "${file_name^}:" --ncols 80 \
      --bar-format "${BAR_FORMAT}" --total ${total} >> "${log_file}.tqdm"

  if has_failed; then
    log ERROR "Script ${file_name}.sh failed, process exited!" >> "${log_file}"
    log 'A fatal error occurred, process exited!'
    exit 1
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

  local log_file="/mnt/var/log/stack/${file_name}.log"

  local user_name='root'

  # Impersonate the sudoer user on desktop, stack and tools installation
  if match "${file_name}" '^(desktop|stack|tools)$'; then
    user_name="$(get_setting 'user_name')"

    if has_failed; then
      log ERROR 'Unable to read the user_name setting' >> "${log_file}"
      log 'A fatal error occurred, process exited!'
      exit 1
    fi
  fi

  local total=0

  case "${file_name}" in
    'system') total=2060;;
    'desktop') total=2750;;
    'stack') total=270;;
    'tools') total=1900;;
  esac

  local script_file="/opt/stack/scripts/${file_name}.sh"

  arch-chroot /mnt runuser -u "${user_name}" -- "${script_file}" 2>&1 |
    tee -a "${log_file}" 2>&1 |
    tqdm --desc "${file_name^}:" --ncols 80 \
      --bar-format "${BAR_FORMAT}" --total ${total} >> "${log_file}.tqdm"
  
  if has_failed; then
    log ERROR "Script ${file_name}.sh failed, process exited!" >> "${log_file}"
    log 'A fatal error occurred, process exited!'
    exit 1
  fi
}

# Restarts the system.
restart () {
  # Copy the installation log files to the new system
  cp /var/log/stack/* /mnt/var/log/stack

  # Append all logs in chronological order
  cat /mnt/var/log/stack/detection.log \
    /mnt/var/log/stack/report.log \
    /mnt/var/log/stack/diskpart.log \
    /mnt/var/log/stack/bootstrap.log \
    /mnt/var/log/stack/system.log \
    /mnt/var/log/stack/desktop.log \
    /mnt/var/log/stack/stack.log \
    /mnt/var/log/stack/tools.log \
    /mnt/var/log/stack/cleaner.log >> /mnt/var/log/stack/all.log

  # Clean redundant log files from archiso media
  rm -rf /var/log/stack
  
  log '\nInstallation process has been completed'
  log 'Rebooting the system in 15 secs...'

  sleep 15
  umount -R /mnt || log 'Ignoring busy mount points'
  reboot
}

clear

cat << EOF
░░░█▀▀░▀█▀░█▀█░█▀▀░█░█░░░
░░░▀▀█░░█░░█▀█░█░░░█▀▄░░░
░░░▀▀▀░░▀░░▀░▀░▀▀▀░▀░▀░░░
EOF

log '\nWelcome to the Stack Linux installer.'
log 'Base your development stack on Arch Linux!'

confirm 'Do you want to proceed?'

if is_not_given "${REPLY}" || is_no "${REPLY}"; then
  log 'Sure, maybe next time!'
  exit 0
fi

init &&
  run askme &&
  run detection &&
  report &&
  run diskpart &&
  run bootstrap &&
  install system &&
  install desktop &&
  install stack &&
  install tools &&
  run cleaner &&
  restart
