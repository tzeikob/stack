#!/bin/bash

set -Eeo pipefail

source src/commons/error.sh
source src/commons/logger.sh
source src/commons/validators.sh
source src/commons/math.sh

SETTINGS_FILE=./settings.json

# Installs the node javascript runtime engine.
install_node () {
  log INFO 'Installing the node runtime engine...'

  local user_name=''
  user_name="$(jq -cer '.user_name' "${SETTINGS_FILE}")" ||
    abort ERROR 'Unable to read user_name setting.'

  local nvm_home="/home/${user_name}/.nvm"

  local previous_dir=${PWD}

  git clone https://github.com/nvm-sh/nvm.git "${nvm_home}" 2>&1 &&
    cd "${nvm_home}" &&
    git checkout `git describe --abbrev=0 --tags --match "v[0-9]*" $(git rev-list --tags --max-count=1)` 2>&1 &&
    cd "${previous_dir}"
  
  if has_failed; then
    log WARN 'Failed to install node version manager.'
    return 0
  fi

  log INFO 'Node version manager has been installed.'

  local bashrc_file="/home/${user_name}/.bashrc"

  local hooks=''
  hooks+=$'\nexport NVM_DIR="${HOME}/.nvm"'
  hooks+=$'\n[ -s "${NVM_DIR}/nvm.sh" ] && \. "${NVM_DIR}/nvm.sh"'
  hooks+=$'\n[ -s "${NVM_DIR}/bash_completion" ] && \. "${NVM_DIR}/bash_completion"'
  hooks+=$'\nexport PATH="./node_modules/.bin:${PATH}"'

  echo "${hooks}" >> "${bashrc_file}" ||
    log WARN 'Failed to add node hooks to bashrc.'

  log INFO 'Installing the latest node version...'

  \. "${nvm_home}/nvm.sh" 2>&1 &&
    nvm install --no-progress node 2>&1 ||
    log WARN 'Failed to install the latest version of node.'

  log INFO 'Node runtime engine has been installed.'
}

# Installs the go programming language.
install_go () {
  log INFO 'Installing the go programming language...'

  sudo pacman -S --needed --noconfirm go go-tools 2>&1 &&
    log INFO 'Go programming language has been installed.' ||
    log WARN 'Failed to install go programming language.'
}

# Installs the rust programming language.
install_rust () {
  log INFO 'Installing the rust programming language...'

  sudo pacman -S --needed --noconfirm rustup 2>&1
  
  if has_failed; then
    log WARN 'Failed to install rust programming language.'
    return 0
  fi

  log INFO 'Rustup has been installed.'

  log INFO 'Setting the default tool chain...'

  rustup default stable 2>&1 &&
    log INFO 'Rust default tool chain set to stable.' ||
    log WARN 'Failed to set default tool chain.'

  log INFO 'Rust programming language has been installed.'
}

# Installs the docker engine.
install_docker () {
  log INFO 'Installing the docker engine...'

  sudo pacman -S --needed --noconfirm docker docker-compose 2>&1
  
  if has_failed; then
    log WARN 'Failed to install docker engine.'
    return 0
  fi

  log INFO 'Docker packages have been installed.'

  sudo systemctl enable docker.service 2>&1 &&
    log INFO 'Docker service has been enabled.' ||
    log WARN 'Failed to enable docker service.'

  local user_name=''
  user_name="$(jq -cer '.user_name' "${SETTINGS_FILE}")" ||
    abort ERROR 'Unable to read user_name setting.'

  sudo usermod -aG docker "${user_name}" 2>&1 &&
    log INFO 'User added to the docker user group.' ||
    log WARN 'Failed to add user to docker group.'

  log INFO 'Docker egine has been installed.'
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

log INFO 'Script apps.sh started.'
log INFO 'Installing some extra apps...'

if equals "$(id -u)" 0; then
  abort ERROR 'Script apps.sh must be run as non root user.'
fi

install_node &&
  install_go &&
  install_rust &&
  install_docker &&
  install_virtual_box &&
  install_postman &&
  install_compass &&
  install_studio3t &&
  install_dbeaver ||
  abort

log INFO 'Script apps.sh has finished.'
