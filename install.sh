#!/bin/bash

set -Eeo pipefail

source src/commons/input.sh
source src/commons/error.sh
source src/commons/logger.sh
source src/commons/validators.sh

SETTINGS=./settings.json

BAR_FORMAT='{desc:10}  {percentage:3.0f}%|{bar}|  ET{elapsed}'

# Initializes the installer.
init () {
  # Reset possibly existing log files
  rm -rf /var/log/stack
  mkdir -p /var/log/stack
  
  # Initialize the settings file
  echo '{}' > "${SETTINGS}"
}

# Reports all the installation settings set by the user.
report () {
  local log_file="/var/log/stack/report.log"

  local query=''
  query='.user_password = "***" | .root_password = "***"'

  local settings=''
  settings="$(jq "${query}" "${SETTINGS}")"

  if has_failed; then
    log ERROR 'Unable to read installation settings.' >> "${log_file}"
    abort 'Unable to read installation settings.'
  fi

  log -n 'Installation settings set to:' > "${log_file}"
  log "${settings}\n" >> "${log_file}"
}

# Executes a preparation task script with the given file name.
# Arguments:
#  file_name: the name of a task script
run () {
  local file_name="${1}"

  # Do not log while running the askme task
  if equals "${file_name}" 'askme'; then
    echo
    bash src/installer/askme.sh || return 1

    echo
    return 0
  fi

  local total=0
  local desc=''

  case "${file_name}" in
    'detection')
      total=15
      desc='Detection'
      ;;
    'diskpart')
      total=90
      desc='Partition'
      ;;
    'bootstrap')
      total=660
      desc='Bootstrap'
      ;;
    'cleaner')
      total=12
      desc='Cleanup'
      ;;
  esac
  
  local log_file="/var/log/stack/${file_name}.log"

  bash src/installer/${file_name}.sh 2>&1 |
    tee -a "${log_file}" 2>&1 |
    tqdm --desc "${desc^}:" --ncols 50 \
      --bar-format "${BAR_FORMAT}" --total ${total} >> "${log_file}.tqdm"

  if has_failed; then
    log ERROR "Script ${file_name}.sh has failed." >> "${log_file}"
    abort 'A fatal error has been occurred.'
  fi
}

# Executes an installation script with the given file name via
# chroot into the installation disk as root or sudoer user.
# Arguments:
#  file_name: the name of an installation script
install () {
  local file_name="${1}"

  local log_file="/mnt/var/log/stack/${file_name}.log"

  local user_name='root'

  # Impersonate the sudoer user on stack and apps installation
  if match "${file_name}" '^(stack|apps)$'; then
    user_name="$(jq -cer '.user_name' "${SETTINGS}")"

    if has_failed; then
      log ERROR 'Unable to read the user_name setting.' >> "${log_file}"
      abort 'Unable to read user_name setting.'
    fi
  fi

  local total=0
  local desc=''

  case "${file_name}" in
    'system')
      total=2060
      desc='System'
      ;;
    'stack')
      total=270
      desc='Stack'
      ;;
    'apps')
      total=1900
      desc='Apps'
      ;;
  esac

  local script_file="src/installer/${file_name}.sh"

  arch-chroot /mnt runuser -u "${user_name}" -- "${script_file}" 2>&1 |
    tee -a "${log_file}" 2>&1 |
    tqdm --desc "${desc^}:" --ncols 50 \
      --bar-format "${BAR_FORMAT}" --total ${total} >> "${log_file}.tqdm"
  
  if has_failed; then
    log ERROR "Script ${file_name}.sh has failed." >> "${log_file}"
    abort 'A fatal error has been occurred.'
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
    /mnt/var/log/stack/stack.log \
    /mnt/var/log/stack/apps.log \
    /mnt/var/log/stack/cleaner.log >> /mnt/var/log/stack/all.log

  # Clean redundant log files from live media
  rm -rf /var/log/stack
  
  log -n 'Installation process has been completed.'
  log 'Rebooting the system in 15 secs...'

  sleep 15
  umount -R /mnt || log 'Ignoring busy mount points.'
  reboot
}

# Shows the welcome screen of the installer.
welcome () {
  clear

  log '░░░█▀▀░▀█▀░█▀█░█▀▀░█░█░░░'
  log '░░░▀▀█░░█░░█▀█░█░░░█▀▄░░░'
  log '░░░▀▀▀░░▀░░▀░▀░▀▀▀░▀░▀░░░'

  log -n 'Welcome to the Stack Linux installer.'
  log 'Base your development stack on Arch Linux.'

  confirm 'Do you want to proceed?' || abort

  if is_not_given "${REPLY}"; then
    abort 'User input is required.'
  fi

  if is_no "${REPLY}"; then
    abort 'Sure, maybe next time.'
  fi
}

if file_not_in_directory "${0}" "${PWD}"; then
  abort ERROR 'Unable to run script out of its parent directory.'
fi

init &&
  welcome &&
  run askme &&
  run detection &&
  report &&
  run diskpart &&
  run bootstrap &&
  install system &&
  install stack &&
  install apps &&
  run cleaner &&
  restart
