#!/bin/bash

set -Eeo pipefail

BAR_FORMAT='{desc:10}  {percentage:3.0f}%|{bar}|  T-{elapsed:8}'

source /opt/stack/scripts/utils.sh

# Initializes the installer.
init () {
  # Reset the log files
  mkdir -p /var/log/stack &&
    rm -rf /var/log/stack/* ||
    fail 'Failed to reset the log files under /var/log/stack'
  
  # Initialize the settings file
  init_settings
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
    return 0
  fi

  local total=0

  case "${file_name}" in
    'detection') total=65;;
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
    fail "Script ${file_name}.sh has failed" >> "${log_file}"
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
    user_name="$(get_setting 'user_name')" ||
      fail 'Unable to read the user_name setting' >> "${log_file}"
  fi

  local total=0

  case "${file_name}" in
    'system') total=2060;;
    'desktop') total=2750;;
    'stack') total=400;;
    'tools') total=6300;;
  esac

  local script_file="/opt/stack/scripts/${file_name}.sh"

  arch-chroot /mnt runuser -u "${user_name}" -- "${script_file}" 2>&1 |
    tee -a "${log_file}" 2>&1 |
    tqdm --desc "${file_name^}:" --ncols 80 \
      --bar-format "${BAR_FORMAT}" --total ${total} >> "${log_file}.tqdm"
  
  if has_failed; then
    fail "Script ${file_name}.sh has failed" >> "${log_file}"
  fi
}

# Restarts the system.
restart () {
  # Copy the installation log files to the new system
  cp /var/log/stack/* /mnt/var/log/stack ||
    log WARN 'Failed to copy installation log files'

  # Append all logs in chronological order
  cat /mnt/var/log/stack/detection.log \
    /mnt/var/log/stack/diskpart.log \
    /mnt/var/log/stack/bootstrap.log \
    /mnt/var/log/stack/system.log \
    /mnt/var/log/stack/desktop.log \
    /mnt/var/log/stack/stack.log \
    /mnt/var/log/stack/tools.log \
    /mnt/var/log/stack/cleaner.log >> /mnt/var/log/stack/all.log ||
    log WARN 'Failed to append log files to /mnt/var/log/stack/all.log'

  # Clean redundant log files from archiso media
  rm -rf /var/log/stack ||
    log WARN 'Failed to remove /var/log/stack folder'
  
  log 'Installation process has been completed'
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

init &&
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
