#!/bin/bash

set -Eeo pipefail

source src/commons/error.sh
source src/commons/logger.sh
source src/commons/validators.sh
source src/commons/math.sh

SETTINGS_FILE=./settings.json

# Installs the google chrome web browser.
install_chrome () {
  log INFO 'Installing the chrome web browser...'

  yay -S --needed --noconfirm --removemake google-chrome 2>&1 &&
    log INFO 'Chrome web browser has been installed.' ||
    log WARN 'Failed to install the chrome web browser.'
}

# Installs the postman client.
install_postman () {
  log INFO 'Installing the postman client...'

  yay -S --needed --noconfirm --removemake postman-bin 2>&1 &&
    log INFO 'Postman client has been installed.' ||
    log WARN 'Failed to install postman client.'
}

# Installs the mongodb compass client.
install_compass () {
  log INFO 'Installing the mongodb compass client...'

  yay -S --needed --noconfirm --removemake mongodb-compass 2>&1 &&
    log INFO 'Mongodb compass client has been installed.' ||
    log WARN 'Failed to install mongodb compass client.'
}

# Installs the free version of the studio3t client.
install_studio3t () {
  log INFO 'Installing the studio3t client...'

  yay -S --needed --noconfirm --removemake studio-3t 2>&1 &&
    log INFO 'Studio3t client has been installed.' ||
    log WARN 'Failed to install studio-3t client.'
}

# Installs the free version of the dbeaver client.
install_dbeaver () {
  log INFO 'Installing the dbeaver client...'

  # Select the jre provider instead of jdk
  printf '%s\n' 2 y | sudo pacman -S --needed dbeaver 2>&1 &&
    log INFO 'Dbeaver client has been installed.' ||
    log WARN 'Failed to install dbeaver client.'
}

# Installs the virtual box.
install_virtual_box () {
  log INFO 'Installing the virtual box...'

  local kernel=''
  kernel="$(jq -cer '.kernel' "${SETTINGS_FILE}")" ||
    abort ERROR 'Unable to read kernel setting.'

  local pkgs='virtualbox virtualbox-guest-iso'

  if equals "${kernel}" 'stable'; then
    pkgs+=' virtualbox-host-modules-arch'
  elif equals "${kernel}" 'lts'; then
    pkgs+=' virtualbox-host-dkms'
  fi

  sudo pacman -S --needed --noconfirm ${pkgs} 2>&1

  if has_failed; then
    log WARN 'Failed to install virtual box.'
    return 0
  fi

  local user_name=''
  user_name="$(jq -cer '.user_name' "${SETTINGS_FILE}")" ||
    abort ERROR 'Unable to read user_name setting.'

  sudo usermod -aG vboxusers "${user_name}" 2>&1 &&
    log INFO 'User added to the vboxusers user group.' ||
    log WARN 'Failed to add user to vboxusers group.'

  log INFO 'Virtual box has been installed.'
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

  local log_file='/var/log/stack/installer/apps.log'

  local lines=0
  lines=$(cat "${log_file}" | wc -l)

  local fake_lines=0
  fake_lines=$(calc "${total} - ${lines}")

  seq ${fake_lines} | xargs -I -- echo '~'
}

log INFO 'Script apps.sh started.'
log INFO 'Installing some extra apps...'

if equals "$(id -u)" 0; then
  abort ERROR 'Script apps.sh must be run as non root user.'
fi

install_chrome &&
  install_postman &&
  install_compass &&
  install_studio3t &&
  install_dbeaver &&
  install_virtual_box ||
  abort

log INFO 'Script apps.sh has finished.'

resolve 1800 && sleep 2
