#!/bin/bash

set -Eeo pipefail

AES=$'╬'
AES_LN=$'╬\n'
KVS=$'▒'

SETTINGS_FILE='/opt/stack/settings.json'

# Resets the installation settings.
init_settings () {
  echo '{}' > "${SETTINGS_FILE}"
}

# Prints the installation settings, where any sensitive
# settings like passwords are hidden.
# Outputs:
#  The installation settings as a JSON object.
print_settings () {
  local mode="${1}"

  # Hide password like properties
  local query='.user_password = "***" | .root_password = "***"'

  jq "${query}" "${SETTINGS_FILE}"
}

# Saves the installation setting with the given key
# to the given value.
# Arguments:
#  key:   the key name of a setting
#  value: any value
save_setting () {
  local key="${1}"
  local value="${2}"

  # Check if the given value is of invalid type
  echo "${value}" | jq -cer 'type' &> /dev/null

  # Consider any value of invalid type as string
  if has_failed; then
    value="\"${value}\""
  fi

  local settings=''
  settings="$(jq -cr ".${key} = ${value}" "${SETTINGS_FILE}")"

  echo "${settings}" > "${SETTINGS_FILE}"
}

# Gets the value of the installation setting with the given key.
# Arguments:
#  key: the key name of a setting
# Outputs:
#  The value of the given setting otherwise none.
get_setting () {
  local key="${1}"

  jq -cer ".${key}" "${SETTINGS_FILE}"
}

# Checks if the setting with the given key is equal
# to the given value.
# Arguments:
#  key:   the key of a setting
#  value: any value
# Returns:
#  0 if the setting is equal to the value otherwise 1.
is_setting () {
  local key="${1}"
  local value="${2}"

  # Check if the given value is of invalid type
  echo "${value}" | jq -cer 'type' &> /dev/null

  # Consider any value of invalid type as string
  if has_failed; then
    value="\"${value}\""
  fi

  local query="select(.${key} == ${value})"

  jq -cer "${query}" "${SETTINGS_FILE}" &> /dev/null
}

# Removes leading and trailing white spaces
# from the given string or input.
# Arguments:
#  input: a string or input of a pipeline
# Outputs:
#  The given input trimmed of trailing spaces.
trim () {
  local input=''

  if [[ -p /dev/stdin ]]; then
    input="$(cat -)"
  else
    input="$@"
  fi

  echo "${input}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

# Asks the user to enter a value, where the answer is
# kept in the global var REPLY.
# Arguments:
#  prompt: a text line
# Outputs:
#  A prompt text line.
ask () {
  local prompt="${1}"

  REPLY=''

  read -rep "${prompt} " REPLY
}

# Asks the user to enter a secret value, the answer is
# kept in the global var REPLY.
# Arguments:
#  prompt: a text line
# Outputs:
#  A prompt text line.
ask_secret () {
  local prompt="${1}"

  REPLY=''

  read -srep "${prompt} " REPLY
}

# Shows a Yes/No menu and asks user to select an option,
# where the selection is kept in the global var REPLY
# either as a yes or no value.
# Arguments:
#  prompt: a text line
# Outputs:
#  A menu of yes or no options.
confirm () {
  local prompt="${1}"

  REPLY=''
  
  local options="no${KVS}No${AES}yes${KVS}Yes"

  echo "${prompt}"

  REPLY="$(echo "${options}" |
    smenu -nm -/ prefix -W "${AES_LN}" -S /\(.*"${KVS}"\)//v)" || return 1

  # Remove the value part from the selected option
  if is_given "${REPLY}"; then
    REPLY="$(echo "${REPLY}" | sed -r "s/(.*)${KVS}.*/\1/")"
  fi
}

# Shows a menu and asks user to pick one option, where
# the selection is kept in the global var REPLY as a
# value equal to the key property of the selected option.
# Arguments:
#  prompt:  a text line
#  options: a JSON array of {key, value} pairs
#  mode:    horizontal, vertical, tabular
#  slots:   number of vertical or tabular slots
# Outputs:
#  A menu of the given options.
pick_one () {
  local prompt="${1}"
  local options="${2}"
  local mode="${3}"
  local slots="${4:-6}"

  REPLY=''

  local len=0
  len="$(echo "${options}" | jq -cer 'length')" || return 1
  
  if [[ ${len} -eq 0 ]]; then
    return 1
  fi

  local args=()
  if equals "${mode}" 'vertical'; then
    args+=(-l -L "${AES}" -n "${slots}")
  elif equals "${mode}" 'tabular'; then
    args+=(-t "${slots}")
  fi

  # Convert options to a line of key${KVS}value${AES} pairs
  options="$(echo "${options}" |
    jq -cer '[.[]|("\(.key)'"${KVS}"'\(.value)")]|join("'"${AES}"'")')" || return 1

  echo "${prompt}"

  REPLY="$(echo "${options}" |
    smenu -nm -/ prefix -W "${AES_LN}" "${args[@]}" -S /\(.*"${KVS}"\)//v)" || return 1

  # Remove the value part from the selected option
  if is_given "${REPLY}"; then
    REPLY="$(echo "${REPLY}" | sed -r "s/(.*)${KVS}.*/\1/")"
  fi
}

# Shows a menu and asks user to pick many options in order,
# where the selection is kept in the global var REPLY as a
# JSON array with elements equal to the key property of every
# selected option.
# Arguments:
#  prompt:  a text line
#  options: a JSON array of {key, value} pairs
#  mode:    horizontal, vertical, tabular
#  slots:   number of vertical or tabular slots
# Outputs:
#  A menu of the given options.
pick_many () {
  local prompt="${1}"
  local options="${2}"
  local mode="${3}"
  local slots="${4:-6}"

  REPLY=''

  local len=0
  len="$(echo "${options}" | jq -cer 'length')" || return 1
  
  if [[ ${len} -eq 0 ]]; then
    return 1
  fi

  local args=()
  if equals "${mode}" 'vertical'; then
    args+=(-l -L "${AES}" -n "${slots}")
  elif equals "${mode}" 'tabular'; then
    args+=(-t "${slots}")
  fi

  # Convert options to a line of key${KVS}value${AES} pairs
  options="$(echo "${options}" |
    jq -cer '[.[]|("\(.key)'"${KVS}"'\(.value)")]|join("'"${AES}"'")')" || return 1

  echo "${prompt}"

  REPLY="$(echo "${options}" |
    smenu -nm -/ prefix -W "${AES_LN}" "${args[@]}" -S /\(.*"${KVS}"\)//v -P "${AES}")" || return 1

  # Convert selected options to a JSON array of their keys
  if is_given "${REPLY}"; then
    REPLY="$(echo "${REPLY}" | awk -F"${AES}" '{
      out=""
      for (i=1;i<=NF;i++) {
        gsub(/('"${KVS}"'.*$)/, "", $i);
        out=out "\""$i"\","
      }
      print out
    }')"

    # Remove last post fixed comma
    if match "${REPLY}" ',$'; then
      REPLY="[${REPLY::-1}]"
    fi
  fi
}

# Checks if the given value is empty.
# Arguments:
#  value: any value
# Returns:
#  0 if value is empty otherwise 1.
is_empty () {
  local value="${1}"

  if [[ -z "${value}" ]] || [[ "${value}" == '' ]]; then
    return 0
  fi

  return 1
}

# An inverse version of is_empty.
is_not_empty () {
  is_empty "${1}" && return 1 || return 0
}

# An inverse version of is_empty.
is_given () {
  is_empty "${1}" && return 1 || return 0
}

# An inverse version of is_given.
is_not_given () {
  is_given "${1}" && return 1 || return 0
}

# Checks if the given value is integer number within
# the optionally given range.
# Arguments:
#  value: any number value
#  range: [min,max] or none
# Returns:
#  0 if value is integer otherwise 1.
is_integer () {
  local value="${1}"
  local range="${2}"

  local integer='(0|-?[1-9][0-9]*)'

  if not_match "${value}" "^${integer}\$"; then
    return 1
  fi

  if is_given "${range}"; then
    if not_match "${range}" "\[${integer}?,${integer}?\]"; then
      return 1
    fi

    local min=''
    min="$(echo "${range:1:-1}" | cut -d ',' -f 1)"

    if is_given "${min}" && [[ ${value} -lt ${min} ]]; then
      return 1
    fi

    local max=''
    max="$(echo "${range:1:-1}" | cut -d ',' -f 2)"

    if is_given "${max}" && [[ ${value} -gt ${max} ]]; then
      return 1
    fi
  fi

  return 0
}

# An inverse version of is_integer.
is_not_integer () {
  is_integer "${1}" "${2}" && return 1 || return 0
}

# Checks if the file with the given path exists.
# Arguments:
#  path: the path of a file
# Returns:
#  0 if file exists otherwise 1.
file_exists () {
  local path="${1}"
  
  if [[ ! -f "${path}" ]]; then
    return 1
  fi

  return 0
}

# An inverse version of file_exists.
file_not_exists () {
   file_exists "${1}" && return 1 || return 0
}

# Checks if the directory with the given path exists.
# Arguments:
#  path: the path of a directory
# Returns:
#  0 if directory exists otherwise 1.
directory_exists () {
  local path="${1}"

  if [[ ! -d "${path}" ]]; then
    return 1
  fi

  return 0
}

# An inverse version of directory_exists.
directory_not_exists () {
 directory_exists "${1}" && return 1 || return 0
}

# Checks if the symlink with the given path exists.
# Arguments:
#  path: a symlink path
# Returns:
#  0 if symlink exists otherwise 1.
symlink_exists () {
  local path="${1}"

  if [[ ! -L "${path}" ]]; then
    return 1
  fi

  return 0
}

# An inverse version of symlink_exists.
symlink_not_exists () {
  symlink_exists "${1}" && return 1 || return 0
}

# Checks if the given path is a block device.
# Arguments:
#  path: any path
# Returns:
#  0 if path is block device otherwise 1.
is_block_device () {
  local path="${1}"
  
  if [[ ! -b "${path}" ]]; then
    return 1
  fi

  return 0
}

# An inverse version of is_block_device.
is_not_block_device () {
  is_block_device "${1}" && return 1 || return 0
}

# Checks if the given value equals to yes.
# Arguments:
#  value: any value
# Returns:
#  0 if value is yes otherwise 1.
is_yes () {
  local value="${1}"

  if not_match "${value}" '^(y|yes)$'; then
    return 1
  fi

  return 0
}

# An inverse version of is_yes.
is_not_yes () {
  is_yes "${1}" && return 1 || return 0
}

# Checks if the given value equals to no.
# Arguments:
#  value: any value
# Returns:
#  0 if value is no otherwise 1.
is_no () {
  local value="${1}"

  if not_match "${value}" '^(n|no)$'; then
    return 1
  fi

  return 0
}

# An inverse version of is_no.
is_not_no () {
  is_no "${1}" && return 1 || return 0
}

# Checks if the given value equals to on.
# Arguments:
#  value: any value
# Returns:
#  0 if value is on otherwise 1.
is_on () {
  local value="${1}"

  if not_equals "${value}" 'on'; then
    return 1
  fi

  return 0
}

# An inverse version of is_on.
is_not_on () {
  is_on "${1}" && return 1 || return 0
}

# Checks if the given value equals to off.
# Arguments:
#  value: any value
# Returns:
#  0 if value is off otherwise 1.
is_off () {
  local value="${1}"

  if not_equals "${value}" 'off'; then
    return 1
  fi

  return 0
}

# An inverse version of is_off.
is_not_off () {
  is_off "${1}" && return 1 || return 0
}

# Checks if the given exit status code is non-zero
# which indicates the last command has failed. If no
# code is given the function will consider as exit
# code the current value of $?.
# Arguments:
#  code: an exit status code
# Returns:
#  0 if exit code is non-zero otherwise 1.
has_failed () {
  # Save exit code set by the previous command
  local code=$?

  if is_given "${1}"; then
    code="${1}"
  fi

  if [[ ${code} -ne 0 ]]; then
    return 0
  fi

  return 1
}

# An inverse version of has_failed.
has_not_failed () {
  has_failed "${1}" && return 1 || return 0
}

# Checks if the given value is matching with the given regex.
# Arguments:
#  value: any value
#  re:    a regular expression
# Returns:
#  0 if there is match otherwise 1.
match () {
  local value="${1}"
  local re="${2}"

  if is_not_given "${value}" || is_not_given "${re}"; then
    return 1
  fi

  if [[ ! "${value}" =~ ${re} ]]; then
    return 1
  fi

  return 0
}

# An inverse version of match.
not_match () {
  match "${1}" "${2}" && return 1 || return 0
}

# Checks if the given values are equal.
# Arguments:
#  a: any value
#  b: any value
# Returns:
#  0 if value a equals b otherwise 1.
equals () {
  local a="${1}"
  local b="${2}"

  if [[ "${a}" != "${b}" ]]; then
    return 1
  fi

  return 0
}

# An inverse version of equals.
not_equals () {
  equals "${1}" "${2}" && return 1 || return 0
}

