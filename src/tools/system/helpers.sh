#!/bin/bash

source src/commons/error.sh
source src/commons/math.sh
source src/commons/validators.sh

# Returns various info of the system status.
# Outputs:
#  A json object of system data.
find_system_status () {
  local fields='OS|Kernel|Shell'

  local status=''

  status+="$(neofetch --off --stdout |
    awk -F':' '/^('"${fields}"')/{
      gsub(/^[ \t]+/,"",$2)
      gsub(/[ \t]+$/,"",$2)

      frm="\"%s\":\"%s\","
      printf frm, tolower($1), $2
    }'
  )" || return 1

  # Remove the last extra comma after the last field
  status="${status:+${status::-1}}"

  status="{${status}}"
  
  local libalpm_version=''
  libalpm_version="$(pacman -V | grep "Pacman v" | awk '{print $6}' | sed 's/v\(.*\)/\1/')" || return 1

  status="$(echo "${status}" | jq -cer ".libalpm = \"${libalpm_version}\"")" || return 1

  local pacman_version=''
  pacman_version="$(pacman -V | grep "Pacman v" | awk '{print $3}' | sed 's/v\(.*\)/\1/')" || return 1

  status="$(echo "${status}" | jq -cer ".pacman = \"${pacman_version}\"")" || return 1

  local yay_version=''
  yay_version="$(yay -V | awk '{print $2}' | sed 's/v\(.*\)/\1/')" || return 1

  status="$(echo "${status}" | jq -cer ".yay = \"${yay_version}\"")" || return 1

  echo "${status}"
}

# Returns the settings of the reflector service.
# Outputs:
#  A json object of reflector settings.
find_reflector_settings () {
  local settings=''

  local reflector_conf='/etc/xdg/reflector/reflector.conf'

  local countries=''
  countries="$(grep -E '^--country' "${reflector_conf}" | cut -d ' ' -f 2)" || return 1

  settings+="\"mirrors\": \"${countries}\","
  
  local age=''
  age="$(grep -E '^--age' "${reflector_conf}" | cut -d ' ' -f 2)" || return 1

  settings+="\"age\": \"${age}\","

  local latest=''
  latest="$(grep -E '^--latest' "${reflector_conf}" | cut -d ' ' -f 2)" || return 1

  settings+="\"latest\": \"${latest}\""
  
  echo "{${settings}}"
}

# Find all the packages installed to the system
# via the package managers pacman and yay (AUR).
# Returns:
#  A json object with the pacman and AUR list packages.
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
#  A json list of pacman packages.
find_outdated_pacman_packages () {
  local query=''
  query+='name: .[0] | split(" ") | .[0],'
  query+='current: .[0] | split(" ") | .[1],'
  query+='latest: .[1]'

  query="[inputs | split(\" -> \") | {${query}}]"
  
  local pacman_pkgs=''
  pacman_pkgs="$(checkupdates | jq -Rn "${query}")"

  if is_true "$? = 1"; then
    return 1
  elif is_true "$? = 2"; then
    pacman_pkgs='[]'
  fi

  echo "${pacman_pkgs}"
}

# Find the list of outdated AUR packages.
# Returns:
#  A json list of AUR packages.
find_outdated_aur_packages () {
  local query=''
  query+='name: .[0] | split(" ") | .[0],'
  query+='current: .[0] | split(" ") | .[1],'
  query+='latest: .[1]'
  query="[inputs | split(\" -> \") | {${query}}]"

  local aur_pkgs=''
  aur_pkgs="$(yay -Qum | jq -Rn "${query}")"

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

  match "${value}" '^(pacman|aur)$'
}

# An inverese alias of the is_package_repository.
is_not_package_repository () {
  ! is_package_repository "${1}"
}

# Shows a menu asking the user to select many mirror countries.
# Outputs:
#  A menu of mirror countries.
pick_mirror_countries () {
  local countries=''

  countries="$(reflector --list-countries | tail -n +3 | awk '{
      match($0, /(.*)([A-Z]{2})\s+([0-9]+)/, a)
      gsub(/[ \t]+$/, "", a[1])

      frm = "{\"key\": \"%s\", \"value\": \"%s\"},"
      printf frm, a[2], a[1]" ["a[3]"]"
    }'
  )" || return 1

  # Remove the extra comma from the last element
  countries="[${countries:+${countries::-1}}]"

  local len=0
  len=$(echo "${countries}" | jq -cer 'length') || return 1

  if is_true "${len} = 0"; then
    log 'No mirror countries have found.'
    return 2
  fi

  pick_many 'Select mirror countries:' "${countries}" 'vertical' || return $?
}
