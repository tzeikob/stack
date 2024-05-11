#!/bin/bash

set -o pipefail

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

