#!/bin/bash

set -Eeo pipefail

source /opt/stack/commons/logger.sh
source /opt/stack/commons/validators.sh

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

# Aborts the current process logging the given error message.
# Arguments:
#  level:   optionally one of INFO, WARN, ERROR
#  message: an error message to print
# Outputs:
#  An error messsage.
abort () {
  local level message

  if [[ $# -ge 2 ]]; then
    level="${1}"
    message="${2}"
  elif [[ $# -eq 1 ]]; then
    message="${1}"
  fi

  # If level is given script is logging, otherwise screen is logging
  if is_given "${message}"; then
    if is_given "${level}"; then
      log "${level}" "${message}"
      log "${level}" 'Process has been exited.'
    else
      log "\n${message}"
      log 'Process has been exited.'
    fi
  else
    if is_given "${level}"; then
      log "${level}" 'Process has been exited.'
    else
      log '\nProcess has been exited.'
    fi
  fi

  exit 1
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
