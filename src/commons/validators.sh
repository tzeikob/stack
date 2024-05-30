#!/bin/bash

set -Eeo pipefail

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

# Checks if the given value is an integer number within
# the optionally given range of values.
# Arguments:
#  value: any number value
#  range: [min,max] or none
# Returns:
#  0 if value is an integer otherwise 1.
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
  local value="${1,,}"

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
  local value="${1,,}"

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
  local value="${1,,}"

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
  local value="${1,,}"

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
}

# An inverse version of is_time.
is_not_time () {
  is_time "${1}" && return 1 || return 0
}
