#!/bin/bash

set -o pipefail

AES=$'╬'
AES_LN=$'╬\n'
KVS=$'▒'

# Shows a prompt asking the user to enter the
# next command, which is kept in the global var REPLY.
# Arguments:
#  label: the label of the prompt
# Outputs:
#  A minimal prompt line.
prompt () {
  local label="${1:-"prompt"}"

  read -rep "${label}>> " REPLY
  
  history -s "${REPLY}"
}

# Asks the user to enter a value, which is validated
# by the optional regular expression. The answer is
# kept in the global var REPLY.
# Arguments:
#  prompt: a text line
#  re:     an optional regular expression
# Outputs:
#  A prompt text line.
# Returns:
#  1 if optional validation failed otherwise 0.
ask () {
  local prompt="${1}"
  local re="${2}"

  REPLY=''

  read -rep "${prompt} " REPLY

  if is_given "${re}" && not_match "${REPLY}" "${re}"; then
    return 1
  fi

  return 0
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

# Invalidates user's cached credentials and enforcing
# new password authentication.
# Returns:
#  0 if succeeded otherwise 1.
authenticate_user () {
  # Skip authentication for the root user
  if equals "$(id -u)" 0; then
    return 0
  fi

  echo 'Permission needed for this operation.'

  # Invalidate user's cached credentials
  sudo -K

  # Mimic authentication with a dry run
  sudo /usr/bin/true &> /dev/null

  if has_failed; then
    echo 'Sorry incorrect password!'
    return 2
  fi

  return 0
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
  len="$(count "${options}")" || return 1
  
  if is_true "${len} = 0"; then
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
    LC_CTYPE=en_US.UTF-8 smenu -nm -/ prefix -W "${AES_LN}" "${args[@]}" -S /\(.*"${KVS}"\)//v)" || return 1

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
  len="$(count "${options}")" || return 1
  
  if is_true "${len} = 0"; then
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
    LC_CTYPE=en_US.UTF-8 smenu -nm -/ prefix -W "${AES_LN}" "${args[@]}" -S /\(.*"${KVS}"\)//v -P "${AES}")" || return 1

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

# Gets a JSON object's property its key matching the
# given query, where query could be any valid jq query.
# Arguments:
#  object: a JSON object
#  query:  a jq query
# Outputs:
#  The value of the given key.
get () {
  local object="${1}"
  local query="${2:-"."}|if . then . else \"\" end"

  local result=''
  result="$(echo "${object}" | jq -cr "${query}")" || return 1

  echo "${result}"
}

# Counts the number of elements in the given JSON array.
# Arguments:
#  array: a JSON array object
# Outputs:
#  The number of array elements.
count () {
  local array="${1}"

  local result=0
  result="$(echo "${array}" | jq -cer 'length')" || return 1

  echo "${result}"
}

# Returns the md5 hash of the given string value
# truncated to the first given number of characters.
# Arguments:
#  value:  a string value
#  length: the number of character to keep
# Outputs:
#  A truncated md5 hash value.
get_hash () {
  local value="${1}"
  local length="${2:-32}"

  echo "${value}" | md5sum | cut "-c1-${length}"
}

# Plays a short success or failure beep sound according
# to the given exit status code which then passes it back.
# Arguments:
#  exit_code: an integer positive value
# Returns:
#  The same given exit code.
beep () {
  local exit_code="${1}"

  local sound='normal'

  if has_failed "${exit_code}"; then
    sound='critical'
  fi

  local sound_file="/usr/share/sounds/stack/${sound}.wav"

  if command -v pw-play &> /dev/null; then
    LC_ALL=en_US.UTF-8 pw-play --volume=0.5 "${sound_file}" &> /dev/null &
  elif command -v aplay &> /dev/null; then
    aplay "${sound_file}" &> /dev/null &
  fi

  return ${exit_code}
}

# Sets the script mode to on or off by setting a
# global variable with name ON_SCRIPT_MODE.
# Arguments:
#  mode: either on or off
set_script_mode () {
  local mode="${1}"

  if equals "${mode}" 'on'; then
    ON_SCRIPT_MODE='true'
  else
    ON_SCRIPT_MODE='false'
  fi
}

# Checks if we run on script mode or not by checking
# if the flag ON_SCRIPT_MODE has been set indicating
# the call was made by a not human.
# Returns:
#  0 if run on script mode otherwise 1.
on_script_mode () {
  if is_empty "${ON_SCRIPT_MODE}"; then
    return 1
  fi

  if is_not_true "${ON_SCRIPT_MODE}"; then
    return 1
  fi

  return 0
}

# An inverse version of on_script_mode.
not_on_script_mode () {
  on_script_mode && return 1 || return 0
}

# An alias version of not_on_script_mode.
on_user_mode () {
  not_on_script_mode && return 0 || return 1
}

# Sets the quiet mode to on or off by setting a
# global variable with name ON_QUIET_MODE.
# Arguments:
#  mode: either on or off
set_quiet_mode () {
  local mode="${1}"

  if equals "${mode}" 'on'; then
    ON_QUIET_MODE='true'
  else
    ON_QUIET_MODE='false'
  fi
}

# Checks if the script is running on quiet mode by
# checking if the global quiet variable has set.
# Returns:
#  0 if run on quiet mode otherwise 1.
on_quiet_mode () {
  if is_empty "${ON_QUIET_MODE}"; then
    return 1
  fi

  if is_not_true "${ON_QUIET_MODE}"; then
    return 1
  fi

  return 0
}

# An inverse version of on_quiet_mode.
not_on_quiet_mode () {
  on_quiet_mode && return 1 || return 0
}

# An alias version of not_on_quiet_mode.
on_loud_mode () {
  not_on_quiet_mode && return 0 || return 1
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
# the optionalyy given range.
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

# Checks if the given value is a valid date.
# Arguments:
#  value: a date value
# Returns:
#  0 if value is date otherwise 1.
is_date () {
  local value="${1}"

  if not_match "${value}" '^[0-9]{2}([0-9]{2})?-[0-9]{2}-[0-9]{2}$'; then
    return 1
  fi
  
  date -d "${value}" &> /dev/null
  
  if has_failed; then
    return 1
  fi

  return 0
}

# An inverse version of is_date.
is_not_date () {
  is_date "${1}" && return 1 || return 0
}

# Checks if the given time is valid.
# Arguments:
#  time: a time in hh:mm:ss form
# Returns:
#  0 if time is valid otherwise 1.
is_time () {
  local time="${1}"

  if not_match "${time}" '^[0-9]{2}:[0-9]{2}(:[0-9]{2})?$'; then
    return 1
  fi

  date -d "1970-01-01T${time}" &> /dev/null

  if has_failed; then
    return 1
  fi

  return 0
}

# An inverse version of is_time.
is_not_time () {
  is_time "${1}" && return 1 || return 0
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

# Checks if the given value is a valid on/off toggle.
# Arguments:
#  value: any value
# Returns:
#  0 if value is either on or off otherwise 1.
is_toggle () {
  local value="${1}"

  if is_not_on "${value}" && is_not_off "${value}"; then
    return 1
  fi

  return 0
}

# An inverse version of is_toggle.
is_not_toggle () {
  is_toggle "${1}" && return 1 || return 0
}

# Checks if the given value or expression is true,
# where expression could be any mathematical comparison
# like 0 < 5 < 10 or so.
# Arguments:
#  value: any boolean value or expression
# Returns:
#  0 if value is true otherwise 1.
is_true () {
  local value="${1}"

  local result='false'
  result="$(qalc -t "${value}")" || return 1

  if equals "${result}" 'true' || [[ ${result} -eq 1 ]]; then
    return 0
  fi

  return 1
}

# An inverse version of is_true.
is_not_true () {
  is_true "${1}" && return 1 || return 0
}

# A alias version of is_not_true.
is_false () {
  is_not_true "${1}" && return 0 || return 1
}

# An inverse version of is_false.
is_not_false () {
  is_false "${1}" && return 1 || return 0
}

# Checks if the given value is boolean.
# Arguments:
#  value: any value
# Returns:
#  0 if value is boolean otherwise 1.
is_boolean () {
  local value="${1}"
  
  if is_not_true "${value}" && is_not_false "${value}"; then
    return 1
  fi

  return 0
}

# An inverse version of is_boolean.
is_not_boolean () {
  is_boolean "${1}" && return 1 || return 0
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

# Calculates the given arithmetic expression.
# Arguments:
#  expression: any arithmetic expression
# Outputs:
#  The result of the arithmetic expression.
calc () {
  local expression="${1}"

  local result=0
  result="$(qalc -t "${expression}")" || return 1

  # Make sure scientific formats like 3e-9 convert to regular form
  result="$(echo "${result}" | awk '{print $0 + 0}')" || return 1

  echo "${result}"
}

# Checks if any processes with the given command
# are running.
# Arguments:
#  re: any regular expression
is_process_up () {
  local re="${1}"
  
  local query=".command|test(\"${re}\")"
  query=".[]|select(${query})"
  
  ps aux | grep -v 'jq' | jc --ps | jq -cer "${query}" &> /dev/null || return 1
}

# An inverse version of is_up.
is_process_down () {
  is_process_up "${1}" && return 1 || return 0
}

# Kills all the processes the command of which match
# the given regular expression.
# Arguments:
#  re: any regular expression
kill_process () {
  local re="${1}"

  pkill --full "${re}" &> /dev/null

  sleep 1
}

