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
  local count=0
  count=$(find ./src -type f -not -name '*.sh' | wc -l) ||
    abort ERROR 'Unable to list source files.'

  if [[ ${count} -gt 0 ]]; then
    log ERROR '[FAILED] No shell files test.'
    return 1
  fi

  log INFO '[PASSED] No shell files test.'
}

# Asserts all func names have a name with lower letters and underscores.
test_valid_func_names () {
  local valid_declaration='^[a-zA-Z_0-9]{1,} \(\) \{$'

  local files=''
  files=($(find ./src -type f -name '*.sh')) ||
    abort ERROR 'Unable to list source files.'

  local file=''
  for file in "${files[@]}"; do
    local funcs=''
    funcs=$(grep '.*( *) *{.*' ${file}) ||
      abort ERROR 'Unable to read function declarations.'

    local func=''
    while read -r func; do
      if [[ ! "${func}" =~ ${valid_declaration} ]]; then
        log ERROR '[FAILED] Valid func names test.'
        log ERROR "[FAILED] Function: ${func}."
        return 1
      fi
    done <<< "${funcs}"
  done

  log INFO '[PASSED] Valid func names test.'
}

# Asserts no func gets overriden by any other func.
test_no_func_overriden () {
  local files=''
  files=($(find ./src -type f -name '*.sh' -not -path './src/tools/*/main.sh')) ||
    abort ERROR 'Unable to list source files.'

  local total_funcs=''

  local file=''
  for file in "${files[@]}"; do
    local funcs=''
    funcs=$(grep '.*( *) *{.*' ${file} | cut -d ' ' -f 1) ||
      abort ERROR 'Unable to read function declarations.'

    total_funcs+=$'\n'"${funcs}"
  done

  local func=''
  while read -r func; do
    if [[ -z "${func}" ]] || [[ "${func}" =~ '^ *$' ]]; then
      continue
    fi

    local occurrences=0
    occurrences=$(echo "${total_funcs}" | grep "^${func}$" | wc -l) ||
      abort ERROR 'Unable to iterate through function declarations.'

    if [[ ${occurrences} -gt 1 ]]; then
      log ERROR '[FAILED] No func overriden test.'
      log ERROR "[FAILED] Function: ${func} [${occurrences}]."
      return 1
    fi
  done <<< "${total_funcs}"

  log INFO '[PASSED] No func overriden test.'
}

test_no_shell_files &&
  test_valid_func_names &&
  test_no_func_overriden &&
  log INFO 'All test assertions have been passed.' ||
  abort ERROR 'Some tests have been failed to pass.'
