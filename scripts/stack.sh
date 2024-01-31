#!/bin/bash

set -Eeo pipefail

source /opt/stack/scripts/utils.sh

# Installs the node javascript runtime engine.
install_node () {
  log 'Installing the node runtime engine...'

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  local nvm_home="/home/${user_name}/.nvm"

  OUTPUT="$(
    git clone https://github.com/nvm-sh/nvm.git "${nvm_home}" 2>&1 &&
      cd "${nvm_home}" &&
      git checkout `git describe --abbrev=0 --tags --match "v[0-9]*" $(git rev-list --tags --max-count=1)` 2>&1 &&
      cd ~
  )" || fail

  log -t file "${OUTPUT}"

  local bashrc_file="/home/${user_name}/.bashrc"

  echo -e '\nexport NVM_DIR="${HOME}/.nvm"' >> "${bashrc_file}" &&
    echo '[ -s "${NVM_DIR}/nvm.sh" ] && \. "${NVM_DIR}/nvm.sh"' >> "${bashrc_file}" &&
    echo '[ -s "${NVM_DIR}/bash_completion" ] && \. "${NVM_DIR}/bash_completion"' >> "${bashrc_file}" || fail

  log 'Node version manager has been installed'

  log 'Installing the latest node version...'

  OUTPUT="$(
    \. "${nvm_home}/nvm.sh" 2>&1 &&
      nvm install --no-progress node 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  log 'Node latest version has been installed'

  echo 'export PATH="./node_modules/.bin:${PATH}"' >> "${bashrc_file}" || fail

  log 'Node runtime engine has been installed\n'
}

# Installs the deno javascript runtime engine.
install_deno () {
  log 'Installing the deno runtime engine...'

  OUTPUT="$(
    sudo pacman -S --noconfirm deno 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  log 'Deno runtime engine has been installed\n'
}

# Installs the bun javascript runtime engine.
install_bun () {
  log 'Installing the bun runtime engine...'

  local url='https://bun.sh/install'

  OUTPUT="$(
    curl "${url}" -sSLo /tmp/bun-install.sh \
      --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60 2>&1 &&
      bash /tmp/bun-install.sh 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  log 'Bun runtime engine has been installed\n'
}

# Installs the go programming language.
install_go () {
  log 'Installing the go programming language...'

  OUTPUT="$(
    sudo pacman -S --noconfirm go go-tools 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  log 'Go programming language has been installed\n'
}

# Installs the rust programming language.
install_rust () {
  log 'Installing the rust programming language...'

  OUTPUT="$(
    sudo pacman -S --noconfirm rustup 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  log 'Setting default tool chain...'

  OUTPUT="$(
    rustup default stable 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  log 'Rust default tool chain set to stable'

  log 'Rust programming language has been installed\n'
}

# Installs the docker egine.
install_docker () {
  log 'Installing the docker engine...'

  OUTPUT="$(
    sudo pacman -S --noconfirm docker docker-compose 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  log 'Enabling the docker service...'

  OUTPUT="$(
    sudo systemctl enable docker.service 2>&1
  )" || fail

  log -t file "${OUTPUT}"

  log 'Docker service has been enabled'

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  sudo usermod -aG docker "${user_name}" || fail

  log "User ${user_name} added to the docker user group"

  log 'Docker egine has been installed\n'
}

log '\nStarting the stack installation process...'

if equals "$(id -u)" 0; then
  fail 'Script stack.sh must be run as non root user'
fi

install_node &&
  install_deno &&
  install_bun &&
  install_go &&
  install_rust &&
  install_docker

sleep 3
