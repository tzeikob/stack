#!/bin/bash

set -Eeo pipefail

source /opt/stack/scripts/utils.sh

# Installs the node javascript runtime engine.
install_node () {
  echo 'Installing the node runtime engine...'

  local user_name=''
  user_name="$(get_setting 'user_name')" || exit 1

  local nvm_home="/home/${user_name}/.nvm"

  export NVM_DIR="${nvm_home}" && (
    git clone https://github.com/nvm-sh/nvm.git "${NVM_DIR}"
    cd "${NVM_DIR}"
    git checkout `git describe --abbrev=0 --tags --match "v[0-9]*" $(git rev-list --tags --max-count=1)`
  ) && \. "${NVM_DIR}/nvm.sh" || exit 1

  local bashrc_file="/home/${user_name}/.bashrc"

  echo -e '\nexport NVM_DIR="${HOME}/.nvm"' >> "${bashrc_file}" &&
    echo '[ -s "${NVM_DIR}/nvm.sh" ] && \. "${NVM_DIR}/nvm.sh"' >> "${bashrc_file}" &&
    echo '[ -s "${NVM_DIR}/bash_completion" ] && \. "${NVM_DIR}/bash_completion"' >> "${bashrc_file}" || exit 1

  echo 'Node version manager has been installed'

  echo 'Installing the latest node version...'

  nvm install --no-progress node || exit 1

  echo "Node latest version $(nvm current) has been installed"

  echo 'export PATH="./node_modules/.bin:${PATH}"' >> "${bashrc_file}" || exit 1

  echo -e 'Node runtime engine has been installed\n'
}

# Installs the deno javascript runtime engine.
install_deno () {
  echo 'Installing the deno runtime engine...'

  sudo pacman -S --noconfirm deno || exit 1

  echo -e 'Deno runtime engine has been installed\n'
}

# Installs the bun javascript runtime engine.
install_bun () {
  echo 'Installing the bun runtime engine...'

  local url='https://bun.sh/install'

  curl "${url}" -sSLo /tmp/bun-install.sh \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60 || exit 1

  bash /tmp/bun-install.sh || exit 1

  echo -e 'Bun runtime engine has been installed\n'
}

# Installs the go programming language.
install_go () {
  echo 'Installing the go programming language...'

  sudo pacman -S --noconfirm go go-tools || exit 1

  echo -e 'Go programming language has been installed\n'
}

# Installs the rust programming language.
install_rust () {
  echo 'Installing the rust programming language...'

  sudo pacman -S --noconfirm rustup || exit 1

  rustup default stable || exit 1

  echo 'Rust default tool chain set to stable'

  echo -e 'Rust programming language has been installed\n'
}

# Installs the docker egine.
install_docker () {
  echo 'Installing the docker engine...'

  sudo pacman -S --noconfirm docker docker-compose || exit 1

  echo 'Enabling the docker service...'

  sudo systemctl enable docker.service || exit 1

  echo 'Docker service has been enabled'

  local user_name=''
  user_name="$(get_setting 'user_name')" || exit 1

  sudo usermod -aG docker "${user_name}" || exit 1

  echo "User ${user_name} added to the docker user group"

  echo -e 'Docker egine has been installed\n'
}

echo -e '\nStarting the stack installation process...'

if equals "$(id -u)" 0; then
  echo -e '\nProcess must be run as non root user'
  exit 1
fi

install_node &&
  install_deno &&
  install_bun &&
  install_go &&
  install_rust &&
  install_docker

echo -e '\nStack installation process has been completed'
echo 'Moving to the tools installation process...'
sleep 5
