#!/bin/bash

set -Eeo pipefail

source /opt/stack/scripts/utils.sh

# Installs the node javascript runtime engine.
install_node () {
  log 'Installing the node runtime engine...'

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  local nvm_home="/home/${user_name}/.nvm"

  git clone https://github.com/nvm-sh/nvm.git "${nvm_home}" 2>&1 &&
    cd "${nvm_home}" &&
    git checkout `git describe --abbrev=0 --tags --match "v[0-9]*" $(git rev-list --tags --max-count=1)` 2>&1 &&
    cd ~
  
  if has_failed; then
    log WARN 'Failed to install node version manager'
    return 0
  fi

  log 'Node version manager has been installed'

  local bashrc_file="/home/${user_name}/.bashrc"

  echo -e '\nexport NVM_DIR="${HOME}/.nvm"' >> "${bashrc_file}" &&
    log 'Nvm export hook added to the .bashrc file' ||
    log WARN 'Failed to add export hook to the .bashrc file'

  echo '[ -s "${NVM_DIR}/nvm.sh" ] && \. "${NVM_DIR}/nvm.sh"' >> "${bashrc_file}" &&
    log 'Nvm source hook added to the .bashrc file' ||
    log WARN 'Failed to add source hook to the .bashrc file'
  
  echo '[ -s "${NVM_DIR}/bash_completion" ] && \. "${NVM_DIR}/bash_completion"' >> "${bashrc_file}" &&
    log 'Nvm completion hook added to the .bashrc file' ||
    log WARN 'Failed to add completion hook to the .bashrc file'

  log 'Installing the latest node version...'

  \. "${nvm_home}/nvm.sh" 2>&1 &&
    nvm install --no-progress node 2>&1 &&
    log 'Node latest version has been installed' ||
    log WARN 'Failed to install the latest version of node'

  echo 'export PATH="./node_modules/.bin:${PATH}"' >> "${bashrc_file}" &&
    log 'Node modules path added to the PATH' ||
    log WARN 'Failed to add node modules path into the PATH'

  log 'Node runtime engine has been installed'
}

# Installs the deno javascript runtime engine.
install_deno () {
  log 'Installing the deno runtime engine...'

  sudo pacman -S --needed --noconfirm deno 2>&1

  if has_failed; then
    log WARN 'Failed to install deno'
    return 0
  fi

  log 'Deno runtime engine has been installed'
}

# Installs the bun javascript runtime engine.
install_bun () {
  log 'Installing the bun runtime engine...'

  local url='https://bun.sh/install'

  curl "${url}" -sSLo /tmp/bun-install.sh \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60 2>&1 &&
    bash /tmp/bun-install.sh 2>&1
  
  if has_failed; then
    log WARN 'Failed to install bun'
    return 0
  fi

  log 'Bun runtime engine has been installed'
}

# Installs the go programming language.
install_go () {
  log 'Installing the go programming language...'

  sudo pacman -S --needed --noconfirm go go-tools 2>&1

  if has_failed; then
    log WARN 'Failed to install go programming language'
    return 0
  fi

  log 'Go programming language has been installed'
}

# Installs the rust programming language.
install_rust () {
  log 'Installing the rust programming language...'

  sudo pacman -S --needed --noconfirm rustup 2>&1
  
  if has_failed; then
    log WARN 'Failed to install rust programming language'
    return 0
  fi

  log 'Rustup has been installed'

  log 'Setting the default tool chain...'

  rustup default stable 2>&1 &&
    log 'Rust default tool chain set to stable' ||
    log WARN 'Failed to set default tool chain'

  log 'Rust programming language has been installed'
}

# Installs the docker egine.
install_docker () {
  log 'Installing the docker engine...'

  sudo pacman -S --needed --noconfirm docker docker-compose 2>&1
  
  if has_failed; then
    log WARN 'Failed to install docker engine'
    return 0
  fi

  log 'Docker packages have been installed'

  sudo systemctl enable docker.service 2>&1 &&
    log 'Docker service has been enabled' ||
    log WARN 'Failed to enable docker service'

  local user_name=''
  user_name="$(get_setting 'user_name')" || fail

  sudo usermod -aG docker "${user_name}" 2>&1 &&
    log 'User added to the docker user group' ||
    log WARN 'Failed to add user to docker group'

  log 'Docker egine has been installed'
}

# Resolves the installaction script by addressing
# some extra post execution tasks.
resolve () {
  # Read the current progress as the number of log lines
  local lines=0
  lines=$(cat /var/log/stack/stack.log | wc -l) ||
    fail 'Unable to read the current log lines'

  local total=1000

  # Fill the log file with fake lines to trick tqdm bar on completion
  if [[ ${lines} -lt ${total} ]]; then
    local lines_to_append=0
    lines_to_append=$((total - lines))

    while [[ ${lines_to_append} -gt 0 ]]; do
      echo '~'
      sleep 0.15
      lines_to_append=$((lines_to_append - 1))
    done
  fi

  return 0
}

log 'Script stack.sh started'
log 'Installing the developemnt stack...'

if equals "$(id -u)" 0; then
  fail 'Script stack.sh must be run as non root user'
fi

install_node &&
  install_deno &&
  install_bun &&
  install_go &&
  install_rust &&
  install_docker

log 'Script stack.sh has finished'

resolve && sleep 3
