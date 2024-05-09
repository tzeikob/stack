#!/bin/bash

set -o pipefail

source /opt/stack/commons/utils.sh
source /opt/stack/commons/logger.sh
source /opt/stack/commons/json.sh
source /opt/stack/commons/math.sh
source /opt/stack/tools/system/helpers.sh

# Shows the current status of system.
# Outputs:
#  A verbose list of text data.
show_status () {
  local fields='OS|Kernel|Shell'

  local status=''
  status+="$(neofetch --off --stdout |
    awk -F':' '/^('"${fields}"')/{
      gsub(/^[ \t]+/,"",$2)
      gsub(/[ \t]+$/,"",$2)
      printf "\"%s\":\"%s\",",tolower($1),$2
    }'
  )" || return 1

  # Remove the last extra comma after the last field
  status="${status:+${status::-1}}"

  status="{${status}}"

  local query=''
  query+='System:    \(.os)\n'
  query+='Kernel:    \(.kernel)\n'
  query+='Shell:     \(.shell)'

  echo "${status}" | jq -cer "\"${query}\"" || return 1
  
  local libalpm_version=''
  libalpm_version="$(pacman -V | grep "Pacman v" | awk '{print $6}' | sed 's/v\(.*\)/\1/')"
  
  echo "Libalpm:   ${libalpm_version}"

  local pacman_version=''
  pacman_version="$(pacman -V | grep "Pacman v" | awk '{print $3}' | sed 's/v\(.*\)/\1/')"
  
  echo "Pacman:    ${pacman_version}"
  
  local yay_version=''
  yay_version="$(yay -V | awk '{print $2}' | sed 's/v\(.*\)/\1/')"
  
  echo "Yay:       ${yay_version}"
  
  local pkgs=0
  pkgs="$(find_installed_packages)" || return 1

  echo
  echo "Packages:  $(echo ${pkgs} | jq -cr '(.pacman|length) + (.aur|length)')"
  echo "Pacman:    $(echo ${pkgs} | jq -cr '.pacman|length')"
  echo "AUR:       $(echo ${pkgs} | jq -cr '.aur|length')"

  echo -ne 'Updates:   Processing...'
  
  local total_updates=''
  total_updates="$(find_outdated_packages | jq -cr '(.pacman|length) + (.aur|length)')" || return 1

  if is_true "${total_updates} = 0"; then
    echo -ne '\r\033[KUpdates:   Up to date\n'
  else
    echo -ne "\r\033[KUpdates:   ${total_updates}\n"
  fi
}

# List the currently install packages filtered
# by the given repository.
# Arguments:
#  repository: pacman, aur or none
# Outputs:
#  A long list of packages.
list_packages () {
  local repository="${1}"

  if is_given "${repository}" && is_not_package_repository "${repository}"; then
    log 'Invalid or unknown repository.'
    return 2
  fi

  local pkgs=''
  pkgs="$(find_installed_packages)"

  if has_failed; then
    log 'Failed to find installed packages.'
    return 2
  fi

  local query=''
  query+='Name:    \(.name)\n'
  query+='Version: \(.version)'
  query="[.[]|\"${query}\"]|join(\"\n\n\")"

  if is_given "${repository}"; then
    query=".${repository}|${query}"
  else
    query=".pacman + .aur|${query}"
  fi

  echo "${pkgs}" | jq -cer "${query}" || return 1
}

# Checks for currently outdated packages filtered
# by the given repository.
# Arguments:
#  repository: pacman, aur or none
# Outputs:
#  A long list of packages.
check_updates () {
  local repository="${1}"

  if is_given "${repository}" && is_not_package_repository "${repository}"; then
    log 'Invalid or unknown repository.'
    return 2
  fi

  log 'Processing outdated packages...'

  local pkgs=''
  pkgs="$(find_outdated_packages)"

  if has_failed; then
    log 'Failed to find outdated packages.'
    return 2
  fi
  
  if is_given "${repository}"; then
    pkgs="$(echo "${pkgs}" | jq -cr ".${repository}")"
  else
    pkgs="$(echo "${pkgs}" | jq -cr '.pacman + .aur')"
  fi

  local len=0
  len="$(get_len "${pkgs}")" || return 1

  if is_true "${len} = 0"; then
    log 'No outdated packages have found.'
    return 0
  fi

  local query=''
  query+='Name:    \(.name)\n'
  query+='Current: \(.current)\n'
  query+='Latest:  \(.latest)'
  query="[.[]|\"${query}\"]|join(\"\n\n\")"

  echo "${pkgs}" | jq -cr "${query}" || return 1
}

