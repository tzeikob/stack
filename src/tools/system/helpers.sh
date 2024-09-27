#!/bin/bash

source src/commons/error.sh
source src/commons/math.sh
source src/commons/validators.sh

# Find all the packages installed to the system
# via the package managers pacman and yay (AUR).
# Returns:
#  A JSON object with the pacman and AUR list packages.
find_installed_packages () {
  local query='[inputs | split(" ") | {name: .[0], version: .[1]}]'
  
  local pacman_pkgs=''
  pacman_pkgs="$(pacman -Qn | jq -Rn "${query}")" || return 1
  
  local aur_pkgs=''
  aur_pkgs="$(pacman -Qm | jq -Rn "${query}")" || return 1

  echo "{\"pacman\": ${pacman_pkgs}, \"aur\": ${aur_pkgs}}"
}

# Find the list of outdated pacman packages.
# Returns:
#  A JSON list of pacman packages.
find_outdated_pacman_packages () {
  local query=''
  query+='name: .[0] | split(" ") | .[0],'
  query+='current: .[0] | split(" ") | .[1],'
  query+='latest: .[1]'

  query="[inputs | split(\" -> \") | {${query}}]"
  
  local pacman_pkgs=''
  pacman_pkgs="$(checkupdates 2> /dev/null | jq -Rn "${query}")"

  if is_true "$? = 1"; then
    return 1
  elif is_true "$? = 2"; then
    pacman_pkgs='[]'
  fi

  echo "${pacman_pkgs}"
}

# Find the list of outdated AUR packages.
# Returns:
#  A JSON list of AUR packages.
find_outdated_aur_packages () {
  local query=''
  query+='name: .[0] | split(" ") | .[0],'
  query+='current: .[0] | split(" ") | .[1],'
  query+='latest: .[1]'
  query="[inputs | split(\" -> \") | {${query}}]"

  local aur_pkgs=''
  aur_pkgs="$(yay -Qum 2> /dev/null | jq -Rn "${query}")"

  if has_failed; then
    aur_pkgs='[]'
  fi

  echo "${aur_pkgs}"
}

# Checks if the given value is a valid package repository.
# Arguments:
#  value: pacman or aur
is_package_repository () {
  local value="${1}"

  if not_match "${value}" '^(pacman|aur)$'; then
    return 1
  fi

  return 0
}

# An inverese alias of the is_package_repository.
is_not_package_repository () {
  is_package_repository "${1}" && return 1 || return 0
}

