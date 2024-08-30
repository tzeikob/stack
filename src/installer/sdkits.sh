#!/bin/bash

set -Eeo pipefail

source src/commons/error.sh
source src/commons/logger.sh
source src/commons/validators.sh
source src/commons/math.sh

SETTINGS=/stack/settings.json

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

# Installs the deno javascript runtime engine.
install_deno () {
  log INFO 'Installing the deno runtime engine...'

  sudo pacman -S --needed --noconfirm deno 2>&1 &&
    log INFO 'Deno runtime engine has been installed.' ||
    log WARN 'Failed to install deno.'  
}

# Installs the bun javascript runtime engine.
install_bun () {
  log INFO 'Installing the bun runtime engine...'

  local url='https://bun.sh/install'

  curl "${url}" -sSLo /tmp/bun-install.sh \
    --connect-timeout 5 --max-time 15 --retry 3 --retry-delay 0 --retry-max-time 60 2>&1 &&
    bash /tmp/bun-install.sh 2>&1 &&
    log INFO 'Bun runtime engine has been installed.' ||
    log WARN 'Failed to install bun.'
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
  user_name="$(jq -cer '.user_name' "${SETTINGS}")" ||
    abort ERROR 'Unable to read user_name setting.'

  sudo usermod -aG docker "${user_name}" 2>&1 &&
    log INFO 'User added to the docker user group.' ||
    log WARN 'Failed to add user to docker group.'

  log INFO 'Docker egine has been installed.'
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

  local lines=0
  lines=$(cat /var/log/stack/sdkits.log | wc -l)

  local fake_lines=0
  fake_lines=$(calc "${total} - ${lines}")

  seq ${fake_lines} | xargs -I -- log '~'
}

log INFO 'Script sdkits.sh started.'
log INFO 'Installing the software development kits...'

if equals "$(id -u)" 0; then
  abort ERROR 'Script sdkits.sh must be run as non root user.'
fi

install_node &&
  install_deno &&
  install_bun &&
  install_go &&
  install_rust &&
  install_docker

log INFO 'Script sdkits.sh has finished.'

resolve 270 && sleep 2
