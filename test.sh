#!/bin/bash

set -Eeo pipefail

# Prints the given log message prefixed with the given log level.
# Arguments:
#  level:   one of INFO, WARN, ERROR
#  message: a message to show
# Outputs:
#  Prints the message in <level> <message> form.
log () {
  local level="${1}"
  local message="${2}"

  printf '%-5s %b\n' "${level}" "${message}"
}

# Aborts the current process logging the given error message.
# Arguments:
#  level:   one of INFO, WARN, ERROR
#  message: an error message to print
# Outputs:
#  An error messsage.
abort () {
  local level="${1}"
  local message="${2}"

  log "${level}" "${message}"
  log "${level}" 'Process has been exited.'

  exit 1
}

# Asserts no other than shell files exist under the src folder.
test_no_shell_files () {
  local files=($(find ./src -type f \! \( -name \*.sh \)))

  if [[ ${#files[@]} -gt 0 ]]; then
    log WARN 'FAILED No shell files test failed.'
    return 1
  fi

  log INFO 'PASSED No shell files test succeed.'
}

test_no_shell_files &&
  log INFO 'All test assertions have passed.' ||
  abort ERROR 'Failed to pass all test assertions.'
