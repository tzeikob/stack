#!/bin/bash

source src/commons/math.sh
source src/commons/validators.sh

# Prints the given log message prefixed with the given log level.
# No arguments means nothing to log on to the console.
# Options:
#  n: print an empty line before, -nn 2 lines and so on
#  u: move up one line and clear it
# Arguments:
#  level:   optionally one of INFO, WARN, ERROR
#  message: an optional message to show
# Outputs:
#  Prints the message in [<level>] <message> form.
log () {
  local OPTIND='' opt=''

  while getopts ':nu' opt; do
    case "${opt}" in
     'n') printf '\n';;
     'u') tput cuu 1; tput cub $(tput cols); tput el;;
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
    return 0
  fi

  if is_given "${level}"; then
    printf '%-5s %b\n' "${level}" "${message}"
  else
    printf '%b\n' "${message}"
  fi
}
