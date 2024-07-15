#!/bin/bash

set -Eeo pipefail

source /opt/stack/commons/process.sh
source /opt/stack/commons/error.sh
source /opt/stack/commons/logger.sh
source /opt/stack/commons/validators.sh

SETTINGS='/opt/stack/installer/settings.json'

# Installs the node javascript runtime engine.
install_node () {
  log INFO 'Installing the node runtime engine...'

  local user_name=''
  user_name="$(jq -cer '.user_name' "${SETTINGS}")" ||
    abort ERROR 'Unable to read user_name setting.'

  local nvm_home="/home/${user_name}/.nvm"

  git clone https://github.com/nvm-sh/nvm.git "${nvm_home}" 2>&1 &&
    cd "${nvm_home}" &&
    git checkout `git describe --abbrev=0 --tags --match "v[0-9]*" $(git rev-list --tags --max-count=1)` 2>&1 &&
    cd ~
  
  if has_failed; then
    log WARN 'Failed to install node version manager.'
    return 0
  fi

  log INFO 'Node version manager has been installed.'

  local bashrc_file="/home/${user_name}/.bashrc"

  echo -e '\nexport NVM_DIR="${HOME}/.nvm"' >> "${bashrc_file}" &&
    log INFO 'Nvm export hook added to the .bashrc file.' ||
    log WARN 'Failed to add export hook to the .bashrc file.'

  echo '[ -s "${NVM_DIR}/nvm.sh" ] && \. "${NVM_DIR}/nvm.sh"' >> "${bashrc_file}" &&
    log INFO 'Nvm source hook added to the .bashrc file.' ||
    log WARN 'Failed to add source hook to the .bashrc file.'
  
  echo '[ -s "${NVM_DIR}/bash_completion" ] && \. "${NVM_DIR}/bash_completion"' >> "${bashrc_file}" &&
    log INFO 'Nvm completion hook added to the .bashrc file.' ||
    log WARN 'Failed to add completion hook to the .bashrc file.'

  log INFO 'Installing the latest node version...'

  \. "${nvm_home}/nvm.sh" 2>&1 &&
    nvm install --no-progress node 2>&1 &&
    log INFO 'Node latest version has been installed.' ||
    log WARN 'Failed to install the latest version of node.'

  echo 'export PATH="./node_modules/.bin:${PATH}"' >> "${bashrc_file}" &&
    log INFO 'Node modules path added to the PATH.' ||
    log WARN 'Failed to add node modules path into the PATH.'

  log INFO 'Node runtime engine has been installed.'
}

# Installs the deno javascript runtime engine.
install_deno () {
  log INFO 'Installing the deno runtime engine...'

  sudo pacman -S --needed --noconfirm deno 2>&1

  if has_failed; then
    log WARN 'Failed to install deno.'
    return 0
  fi

  log INFO 'Deno runtime engine has been installed.'
}

# Installs the bun javascript runtime engine.
install_bun () {
  log INFO 'Installing the bun runtime engine...'

  local url='https://bun.sh/install'

  curl "${url}" -sSLo /tmp/bun-install.sh \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60 2>&1 &&
    bash /tmp/bun-install.sh 2>&1
  
  if has_failed; then
    log WARN 'Failed to install bun.'
    return 0
  fi

  log INFO 'Bun runtime engine has been installed.'
}

# Installs the go programming language.
install_go () {
  log INFO 'Installing the go programming language...'

  sudo pacman -S --needed --noconfirm go go-tools 2>&1

  if has_failed; then
    log WARN 'Failed to install go programming language.'
    return 0
  fi

  log INFO 'Go programming language has been installed.'
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

# Installs the docker egine.
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
  user_name="$(jq -cer '.user_name' "${SETTINGS}")" ||
    abort ERROR 'Unable to read user_name setting.'

  sudo usermod -aG docker "${user_name}" 2>&1 &&
    log INFO 'User added to the docker user group.' ||
    log WARN 'Failed to add user to docker group.'

  log INFO 'Docker egine has been installed.'
}

log INFO 'Script stack.sh started.'
log INFO 'Installing the developemnt stack...'

if equals "$(id -u)" 0; then
  abort ERROR 'Script stack.sh must be run as non root user.'
fi

install_node &&
  install_deno &&
  install_bun &&
  install_go &&
  install_rust &&
  install_docker

log INFO 'Script stack.sh has finished.'

resolve stack 270 && sleep 2
