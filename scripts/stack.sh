#!/bin/bash

set -Eeo pipefail

source /opt/stack/scripts/utils.sh

# Installs the node javascript runtime engine.
install_node () {
  echo -e 'Installing the node runtime engine...'

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  local nvm_home="/home/${user_name}/.nvm"

  git clone https://github.com/nvm-sh/nvm.git "${nvm_home}" &&
    cd "${nvm_home}" &&
    git checkout `git describe --abbrev=0 --tags --match "v[0-9]*" $(git rev-list --tags --max-count=1)` &&
    cd ~ || fail 'Failed to install nvm'

  echo -e 'Nvm has been installed'

  local bashrc_file="/home/${user_name}/.bashrc"

  echo -e '\nexport NVM_DIR="${HOME}/.nvm"' >> "${bashrc_file}" &&
    echo '[ -s "${NVM_DIR}/nvm.sh" ] && \. "${NVM_DIR}/nvm.sh"' >> "${bashrc_file}" &&
    echo '[ -s "${NVM_DIR}/bash_completion" ] && \. "${NVM_DIR}/bash_completion"' >> "${bashrc_file}" ||
    fail 'Failed to add hooks to the .bashrc file'

  echo -e 'Hooks have been added to the .bashrc file'

  echo -e 'Installing the latest node version...'

  \. "${nvm_home}/nvm.sh" &&
    nvm install --no-progress node || fail 'Failed to install node'

  echo -e 'Node latest version has been installed'

  echo 'export PATH="./node_modules/.bin:${PATH}"' >> "${bashrc_file}" ||
    fail 'Failed to add node moules into the PATH'

  echo -e 'Node runtime engine has been installed'
}

# Installs the deno javascript runtime engine.
install_deno () {
  echo -e 'Installing the deno runtime engine...'

  sudo pacman -S --noconfirm deno || fail 'Failed to install deno'

  echo -e 'Deno runtime engine has been installed'
}

# Installs the bun javascript runtime engine.
install_bun () {
  echo -e 'Installing the bun runtime engine...'

  local url='https://bun.sh/install'

  curl "${url}" -sSLo /tmp/bun-install.sh \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60 &&
    bash /tmp/bun-install.sh || fail 'Failed to install bun'

  echo -e 'Bun runtime engine has been installed'
}

# Installs the go programming language.
install_go () {
  echo -e 'Installing the go programming language...'

  sudo pacman -S --noconfirm go go-tools || fail 'Failed to install go'

  echo -e 'Go programming language has been installed'
}

# Installs the rust programming language.
install_rust () {
  echo -e 'Installing the rust programming language...'

  sudo pacman -S --noconfirm rustup || fail 'Failed to install rustup'

  echo -e 'Rustup has been installed'

  echo -e 'Setting the default tool chain...'

  rustup default stable || fail 'Failed to set default tool chain'

  echo -e 'Rust default tool chain set to stable'

  echo -e 'Rust programming language has been installed'
}

# Installs the docker egine.
install_docker () {
  echo -e 'Installing the docker engine...'

  sudo pacman -S --noconfirm docker docker-compose ||
    fail 'Failed to install docker packages'

  echo -e 'Docker packages have been installed'

  sudo systemctl enable docker.service || fail 'Failed to enable docker service'

  echo -e 'Docker service has been enabled'

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  sudo usermod -aG docker "${user_name}" || fail 'Failed to add user to docker group'

  echo -e 'User added to the docker user group'

  echo -e 'Docker egine has been installed'
}

echo -e 'Installing the developemnt stack...'

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
