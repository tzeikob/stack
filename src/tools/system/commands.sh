#!/bin/bash

source src/commons/process.sh
source src/commons/error.sh
source src/commons/logger.sh
source src/commons/auth.sh
source src/commons/math.sh
source src/commons/validators.sh
source src/tools/system/helpers.sh

UPDATES_FILE=/tmp/updates

# Shows the current status of system.
# Outputs:
#  A verbose list of text data.
show_status () {
  local space=11

  local query=''
  query+='\(.os      | lbln("System"))'
  query+='\(.kernel  | lbln("Kernel"))'
  query+='\(.shell   | lbln("Shell"))'
  query+='\(.stack   | olbln("Stack"))'
  query+='\(.libalpm | lbln("Libalpm"))'
  query+='\(.pacman  | lbln("Pacman"))'
  query+='\(.yay     | lbln("Yay"))'

  find_system_status | jq -cer --arg SPC ${space} "\"${query}\"" || return 1

  local query=''
  query+='\(.mirrors              | lbln("Mirrors"))'
  query+='\(.age | unit(" hours") | lbln("Age"))'
  query+='\(.latest               | lbl("Latest"))'

  find_reflector_settings | jq -cer --arg SPC ${space} "\"${query}\"" || return 1
  
  local query=''
  query+='\(.pacman + .aur | length | lbln("Packages"))'
  query+='\(.pacman | length        | lbln("Pacman"))'
  query+='\(.aur | length           | lbl("AUR"))'

  echo
  find_installed_packages | jq -cr --arg SPC ${space} "\"${query}\"" || return 1
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
  query+='\(.name    | lbln("Name"))'
  query+='\(.version | lbl("Version"))'

  query="[.[] | \"${query}\"] | join(\"\n\n\")"

  if is_given "${repository}"; then
    query=".${repository} | ${query}"
  else
    query=".pacman + .aur | ${query}"
  fi

  echo "${pkgs}" | jq -cer --arg SPC 10 "${query}" || return 1
}

# Sets the mirrors of package databases to the given countries.
# Arguments:
#  age:       the hours within a mirror should be synced
#  latest:    the number of most recently synced mirrors 
#  countries: a space separated list of countries
set_mirrors () {
  authenticate_user || return $?

  local age="${1}"
  local latest="${2}"
  local countries=("${@:3}")

  if is_not_integer "${age}" '[1,]'; then
    log 'Invalid age value'
    return 2
  fi

  if is_not_integer "${latest}" '[1,]'; then
    log 'Invalid latest value'
    return 2
  fi
  
  if is_true "${#countries[@]} = 0"; then
    on_script_mode &&
      log 'No mirror countries are given.' && return 2

    pick_mirror_countries || return $?
    is_not_given "${REPLY}" && log 'Mirror countries are required.' && return 2

    countries=($(echo "${REPLY}" | jq -cr '.[]'))
  fi

  countries="$(jq -cr -n '$ARGS.positional | join(",")' --args "${countries[@]}")" || return 1

  log 'Setting the package databases mirrors...'

  sudo reflector --country "${countries}" \
    --age "${age}" --sort age --latest "${latest}" --save /etc/pacman.d/mirrorlist
  
  if has_failed; then
    log 'Unable to fetch package databases mirrors.'
    return 2
  fi

  local conf_file='/etc/xdg/reflector/reflector.conf'

  sudo sed -i "s/^--country.*/--country ${countries}/" "${conf_file}" &&
    sudo sed -i "s/^--latest.*/--latest ${latest}/" "${conf_file}" &&
    sudo sed -i "s/^--age.*/--age ${age}/" "${conf_file}"
  
  if has_failed; then
    log 'Failed to save mirrors settings to reflector.'
    return 2
  fi

  log "Package databases mirrors set to ${countries}."
}

# Checks for currently available outdated packages
# and updates the updates file accordingly.
check_updates () {
  log 'Processing system updates...'

  local updates=''
  updates="$(cat "${UPDATES_FILE}" | jq -cer .)"

  if has_failed; then
    echo '{"status": 2}' > "${UPDATES_FILE}"
  else
    echo "${updates}" | jq -cer '.status = 2' > "${UPDATES_FILE}"
  fi

  local pacman_pkgs=''
  pacman_pkgs="$(find_outdated_pacman_packages)"

  if has_failed; then
    echo '{"status": -1}' > "${UPDATES_FILE}"

    log 'Unable to search for outdated pacman packages.'
    return 2
  fi

  local aur_pkgs=''
  aur_pkgs="$(find_outdated_aur_packages)"

  if has_failed; then
    echo '{"status": -1}' > "${UPDATES_FILE}"

    log 'Unable to search for outdated AUR packages.'
    return 2
  fi

  local pkgs=''
  pkgs="$(jq -ncer --argjson p "${pacman_pkgs}" --argjson a "${aur_pkgs}" '$p + $a')"

  local total=0
  total="$(echo "${pkgs}" | jq -cer 'length')"

  if has_failed || is_not_integer "${total}" || is_true "${total} < 0"; then
    echo '{"status": -1}' > "${UPDATES_FILE}"

    log 'Unable to resolve the total number of updates.'
    return 2
  fi

  if is_true "${total} = 0"; then
    echo '{"status": 0, "total": 0}' > "${UPDATES_FILE}"

    log 'No available updates have found.'
    return 0
  fi

  log "Found ${total} total updates."

  # Update the updates file
  local updates=''
  updates+='"status": 1,'
  updates+="\"total\": ${total},"
  updates+="\"pacman\": ${pacman_pkgs},"
  updates+="\"aur\": ${aur_pkgs}"
  updates="{${updates}}"

  echo "${updates}" > "${UPDATES_FILE}"

  # Send a notification to the user
  if on_script_mode && is_true "${total} > 0"; then
    notify-send -u NORMAL -a 'System Updates' 'Update your system!' \
      "Heads up! Found ${total} updates!"
  fi
}

# Shows the list of available outdated packages.
# Outputs:
#  A long list of outdated packages.
list_updates () {
  local pkgs=''
  pkgs="$(jq -cer '(.pacman//[]) + (.aur//[])' "${UPDATES_FILE}")"

  if has_failed; then
    log 'Unable to read updates file.'
    return 2
  fi

  local total=0
  total="$(echo "${pkgs}" | jq -cer 'length')"

  if has_failed || is_not_integer "${total}" || is_true "${total} < 0"; then
    log 'Unable to resolve the total number of updates.'
    return 2
  fi

  if is_true "${total} = 0"; then
    log 'No available updates have found.'
    return 0
  fi

  # Print all updates in to the console
  local query=''
  query+='\(.name    | lbln("Name"))'
  query+='\(.current | lbln("Current"))'
  query+='\(.latest  | lbl("Latest"))'

  query="[.[] | \"${query}\"] | join(\"\n\n\")"

  echo "${pkgs}" | jq -cr --arg SPC 10 "${query}" || return 1
}

# Applies any available updates to the system.
apply_updates () {
  authenticate_user || return $?

  local prompt=''
  prompt+='This operation may break your system!'
  prompt+='\nPlease consider taking a backup first.'
  prompt+='\nDo you really want to proceed?'

  confirm "${prompt}" || return $?
  is_empty "${REPLY}" && log 'Confirmation is required.' && return 2
  
  if is_not_yes "${REPLY}"; then
    log 'No updates have been applied.'
    return 2
  fi

  local updates=''
  updates="$(jq -cer . "${UPDATES_FILE}")"

  if has_failed; then
    log 'Unable to read the updates file.'
    return 2
  fi

  local total=''
  total="$(echo "${updates}" | jq -cer '(.pacman//[]) + (.aur//[]) | length')"

  if has_failed; then
    log 'Failed to resolve the total number of udpates.'
    return 2
  elif is_true "${total} = 0"; then
    log 'No updates found to be applied.'
    return 2
  fi

  # Mark updates file as state updating
  echo "${updates}" | jq -cer '.status = 3' > "${UPDATES_FILE}"

  if has_failed; then
    # Mark updates file back to the previous state
    echo "${updates}" | jq -cer '.status = 1' > "${UPDATES_FILE}"

    log 'Unable to modify udpates file.'
    return 2
  fi

  # Make sure packages databases are synced
  sudo pacman -Syy

  if has_failed; then
    # Mark updates file back to the previous state
    echo "${updates}" | jq -cer '.status = 1' > "${UPDATES_FILE}"

    log 'Unable to sync packages databases.'
    return 2
  fi

  local failed_total=0

  local query='.pacman//[] | if length > 0 then .[] else "" end'

  local pacman_pkgs=''
  pacman_pkgs="$(echo "${updates}" | jq -cer "${query}")"

  if has_failed; then
    # Mark updates file back to the previous state
    echo "${updates}" | jq -cer '.status = 1' > "${UPDATES_FILE}"

    log 'Unable to read pacman outdated packages.'
    return 2
  fi

  while read -r pkg; do
    if is_empty "${pkg}"; then
      continue
    fi

    local name=''
    name="$(echo "${pkg}" | jq -cr .name)"

    local current=''
    current="$(echo "${pkg}" | jq -cr .current)"

    local latest=''
    latest="$(echo "${pkg}" | jq -cr .latest)"

    log "Updating ${name} from ${current} to ${latest}..."

    sudo pacman --noconfirm --needed -S ${name}

    if has_failed; then
      failed_total=$(calc "${failed_total} + 1")

      log "Package ${name} failed to be updated."
    fi
    
    # Refresh sudo interval
    sudo -v
  done <<< "${pacman_pkgs}"

  local query='.aur//[] | if length > 0 then .[] else "" end'

  local aur_pkgs=''
  aur_pkgs="$(echo "${updates}" | jq -cer "${query}")"

  if has_failed; then
    # Mark updates file back to the previous state
    echo "${updates}" | jq -cer '.status = 1' > "${UPDATES_FILE}"

    log 'Unable to read aur outdated packages.'
    return 2
  fi

  while read -r pkg; do
    if is_empty "${pkg}"; then
      continue
    fi

    local name=''
    name="$(echo "${pkg}" | jq -cr .name)"

    local current=''
    current="$(echo "${pkg}" | jq -cr .current)"

    local latest=''
    latest="$(echo "${pkg}" | jq -cr .latest)"

    log "Updating ${name} from ${current} to ${latest}..."

    yay --noconfirm --needed -S ${name}

    if has_failed; then
      failed_total=$(calc "${failed_total} + 1")
      
      log "Package ${name} failed to be updated."
    fi
    
    # Refresh sudo interval
    sudo -v
  done <<< "${aur_pkgs}"

  # Check again for unfulfiled updates
  check_updates &> /dev/null

  if is_true "${failed_total} > 0"; then
    log "${failed_total} packages failed to be updated."
  fi

  log 'System update has finished.'
}

# Clones and checkouts the latest version of the stack repository
# and exectutes the upgrade script in order to update the tools
# and modules of the stack os system.
upgrade_stack () {
  authenticate_user || return $?

  local prompt=''
  prompt+='This operation may break your system!'
  prompt+='\nPlease consider taking a backup first!'
  prompt+='\nDo you really want to proceed?'

  confirm "${prompt}" || return $?
  is_empty "${REPLY}" && log 'Confirmation is required.' && return 2
  
  if is_not_yes "${REPLY}"; then
    log 'No stack upgrades have been applied.'
    return 2
  fi

  local hash_file='/opt/stack/.hash'

  if file_not_exists "${hash_file}"; then
    log 'Unable to locate the stack hash file.'
    return 2
  fi

  local branch=''
  branch="$(jq -cer '.branch' "${hash_file}")"

  if has_failed || is_empty "${branch}"; then
    log 'Unable to resolve the stack local branch.'
    return 2
  fi

  local local_commit=''
  local_commit="$(jq -cer '.commit' "${hash_file}")"

  if has_failed || is_empty "${local_commit}"; then
    log 'Unable to resolve the stack local commit.'
    return 2
  fi

  local repo_url='https://github.com/tzeikob/stack.git'

  local remote_commit=''
  remote_commit="$(git ls-remote "${repo_url}" "${branch}" | awk '{print $1}')"

  if has_failed; then
    log 'Unable to resolve the stack remote commit.'
    return 2
  fi

  if equals "${local_commit}" "${remote_commit}"; then
    echo 'Stack is up to date, no upgrades found.'
    return 2
  fi

  local repo_home='/tmp/stack'

  sudo rm -rf "${repo_home}"

  git clone --single-branch --branch "${branch}" --depth 1 "${repo_url}" "${repo_home}"

  if has_failed; then
    log "Failed to clone stack branch ${branch}."
    return 2
  fi

  cd "${repo_home}"

  ./upgrade.sh

  sudo rm -rf "${repo_home}"
}
