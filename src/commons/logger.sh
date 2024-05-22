#!/bin/bash

set -Eeo pipefail

source /opt/stack/commons/validators.sh

# Prints the given log message prefixed with the given log level.
# No arguments means nothing to log on to the console.
# Arguments:
#  level:   optionally one of INFO, WARN, ERROR
#  message: an optional message to show
# Outputs:
#  Prints the message in [<level>] <message> form.
log () {
  local level message

  if [[ $# -ge 2 ]]; then
    level="${1}"
    message="${2}"
  elif [[ $# -eq 1 ]]; then
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
