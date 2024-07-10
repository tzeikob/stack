#!/bin/bash

source /opt/stack/commons/error.sh
source /opt/stack/commons/logger.sh
source /opt/stack/commons/math.sh
source /opt/stack/commons/validators.sh
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

# Sets the mirrors of package databases to the given countries.
# Arguments:
#  countries: a space separated list of countries
set_mirrors () {
  local countries=("$@")
  
  if is_true "${#countries[@]} = 0"; then
    on_script_mode &&
      log 'No mirror countries are given.' && return 2

    countries="$(
      reflector --list-countries 2> /dev/null | tail -n +3 | awk '{
        match($0, /(.*)([A-Z]{2})\s+([0-9]+)/, a)
        gsub(/[ \t]+$/, "", a[1])

        frm="{\"key\": \"%s\", \"value\": \"%s\"},"
        printf frm, a[2], a[1]" ["a[3]"]"
      }'
    )"
    
    if has_failed; then
      log 'Unable to fetch mirror countries.'
      return 2
    fi

    # Remove the extra comma from the last element
    countries="[${countries:+${countries::-1}}]"

    pick_many 'Select mirror countries:' "${countries}" 'vertical' || return $?
    is_not_given "${REPLY}" && log 'Mirror countries are required.' && return 2

    countries=($(echo "${REPLY}" | jq -cr '.[]'))
  fi

  log 'Setting the package databases mirrors...'

  reflector --country "${countries}" \
    --age 48 --sort age --latest 40 --save /etc/pacman.d/mirrorlist 2>&1
  
  if has_failed; then
    log 'Unable to fetch package databases mirrors.'
    return 2
  fi

  local conf_file='/etc/xdg/reflector/reflector.conf'

  sed -i "s/# --country.*/--country ${countries}/" "${conf_file}" &&
    sed -i 's/^--latest.*/--latest 40/' "${conf_file}" &&
    echo '--age 48' >> "${conf_file}"
  
  if has_failed; then
    log 'Failed to save mirrors settings to reflector.'
    return 2
  fi

  log "Package databases mirrors set to ${countries[@]}."
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
  len="$(echo "${pkgs}" | jq -cer 'length')" || return 1

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

# Applies the latest updates to the system.
apply_updates () {
  authenticate_user || return $?

  log 'Processing outdated packages...'

  local pkgs=''
  pkgs="$(find_outdated_packages | jq -cer '.pacman + .aur')"

  if has_failed; then
    log 'Failed to find outdated packages.'
    return 2
  fi

  local len=0
  len="$(echo "${pkgs}" | jq -cer 'length')" || return 1

  if is_true "${len} = 0"; then
    log 'No outdated packages have found.'
    return 2
  fi

  local query=''
  query='[.[]|.name]|join(" ")'

  echo "${pkgs}" | jq -cr "${query}" || return 1

  log "Found ${len} total outdated packages."
  confirm 'Do you want to proceed and update them?' || return $?
  is_empty "${REPLY}" && log 'Confirmation is required.' && return 2
  
  if is_not_yes "${REPLY}"; then
    log 'No updates have been applied.'
    return 2
  fi

  sudo pacman --noconfirm -Syu

  if has_failed; then
    log 'Failed to update pacman packages.'
    return 2
  fi

  yay --noconfirm -Syu

  if has_failed; then
    log 'Failed to update aur packages.'
    return 2
  fi

  log -n "${len} packages have been updated."
  log 'System is now up to date.'
}
