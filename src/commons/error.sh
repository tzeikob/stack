#!/bin/bash

source src/commons/logger.sh
source src/commons/validators.sh
source src/commons/math.sh

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

  is_true "${code} != 0"
}

# An inverse version of has_failed.
has_not_failed () {
  ! has_failed "${1}"
}

# Aborts the current process logging the given error message.
# Options:
#  n: print an empty line before, -nn 2 lines and so on
# Arguments:
#  level:   optionally one of INFO, WARN, ERROR
#  message: an error message to print
# Outputs:
#  An error messsage.
abort () {
  local OPTIND='' opt=''

  while getopts ':n' opt; do
    case "${opt}" in
     'n') printf '\n';;
    esac
  done

  # Collect arguments
  shift $((OPTIND - 1))

  local level message

  if is_true "$# >= 2"; then
    level="${1}"
    message="${2}"
  elif is_true "$# = 1"; then
    message="${1}"
  else
    message='An unknown error has occurred!'
  fi

  if is_given "${level}"; then
    log "${level}" "${message}"
    log "${level}" 'Process has been exited.'
  else
    log "${message}"
    log 'Process has been exited.'
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

  local sound_file="/usr/share/sounds/system/${sound}.wav"

  if command -v pw-play &> /dev/null; then
    LC_ALL=en_US.UTF-8 pw-play --volume=0.5 "${sound_file}" 1> /dev/null &
  elif command -v aplay &> /dev/null; then
    aplay -q "${sound_file}" 1> /dev/null &
  fi

  return ${exit_code}
}
