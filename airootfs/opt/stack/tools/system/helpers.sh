#!/bin/bash

source /opt/stack/commons/error.sh
source /opt/stack/commons/math.sh
source /opt/stack/commons/validators.sh

STACK_HASH_FILE=/opt/stack/.hash

# Find all the packages installed to the system
# via the package managers pacman and yay (aur).
# Returns:
#  A JSON object with the pacman and aur list packages.
find_installed_packages () {
  local query='[inputs|split(" ")|{name: .[0], version: .[1]}]'
  
  local pacman_pkgs=''
  pacman_pkgs="$(pacman -Qn | jq -Rn "${query}")" || return 1
  
  local aur_pkgs=''
  aur_pkgs="$(pacman -Qm | jq -Rn "${query}")" || return 1

  echo "{\"pacman\": ${pacman_pkgs}, \"aur\": ${aur_pkgs}}"
}

# Find the list of pacman and aur packages need to be updated.
# Returns:
#  A JSON object of outdated pacman and aur list packages.
find_outdated_packages () {
  local query=''
  query+='name: .[0]|split(" ")|.[0],'
  query+='current: .[0]|split(" ")|.[1],'
  query+='latest: .[1]'
  query="[inputs|split(\" -> \")|{${query}}]"
  
  # List all outdated packages installed via pacman
  local pacman_pkgs=''
  pacman_pkgs="$(checkupdates 2> /dev/null | jq -Rn "${query}")"

  if is_true "$? = 1"; then
    return 1
  elif is_true "$? = 2"; then
    pacman_pkgs='[]'
  fi

  # List all outdated packages installed via the aur repos
  local aur_pkgs=''
  aur_pkgs="$(yay -Qum 2> /dev/null | jq -Rn "${query}")"

  if has_failed; then
    aur_pkgs='[]'
  fi

  echo "{\"pacman\": ${pacman_pkgs}, \"aur\": ${aur_pkgs}}"
}

# Find the list of stack modules need to be updated.
# Returns:
#  A JSON list of stack outdated modules.
find_outdated_stack_modules () {
  if file_not_exists "${STACK_HASH_FILE}"; then
    log 'Unable to locate stack hash file.'
    return 2
  fi

  local branch=''
  branch="$(jq -cer '.branch' "${STACK_HASH_FILE}")"

  if has_failed || is_empty "${branch}"; then
    log 'Unable to resolve the stack branch name.'
    return 2
  fi

  local remote_commit_id=''
  remote_commit_id="$(git ls-remote https://github.com/tzeikob/stack.git "${branch}" | awk '{print $1}')"

  if has_failed; then
    log 'Unable to resolve the stack remote commit id.'
    return 2
  fi

  local local_commit_id=''
  local_commit_id="$(jq -cer '.commit_id' "${STACK_HASH_FILE}")"

  if has_failed || is_empty "${local_commit_id}"; then
    log 'Unable to resolve the stack local commit id.'
    return 2
  fi

  local mods=''

  # No equal commit ids means stack is outdated
  if not_equals "${local_commit_id}" "${remote_commit_id}"; then
    mods+='"name": "stack",'
    mods+="\"current\": \"${local_commit_id:0:7}\","
    mods+="\"latest\": \"${remote_commit_id:0:7}\""
    mods="{${mods}}"
  fi

  echo "[${mods}]"
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

