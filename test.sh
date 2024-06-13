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

# Iterate recursively starting from the given file path
# all the way down following every source file.
# Arguments:
#  root: the root entry file of an execution path
# Outputs:
#  All the source file paths loaded in the execution path.
traverse_files () {
  local root="${1}"

  if [[ -z "${root}" ]] || [[ "${root}" =~ '^ *$' ]]; then
    echo ''
  else
    # Collect all files sourced in the current root file
    local files=''
    files=$(grep -e '^source .*' "${root}" | cut -d ' ' -f 2)

    if [[ $? -gt 1 ]]; then
      return 1
    fi

    if [[ -n "${files}" ]] && [[ ! "${files}" =~ '^ *$' ]]; then
      # Replace after installation paths with the repository locations
      files=$(echo "${files}" | sed -e 's;/opt/stack;./src;')
      
      # Collect recursivelly every sourced file walking the execution path
      local file=''
      while read -r file; do
        echo "${root}"$'\n'"$(traverse_files "${file}")"
      done <<< "${files}"
    else
      echo "${root}"
    fi
  fi
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

# Asserts no func gets overriden on execution paths.
test_no_func_overriden () {
  local roots=(
    ./src/installer/run.sh
    ./src/installer/askme.sh
    ./src/installer/detection.sh
    ./src/installer/diskpart.sh
    ./src/installer/bootstrap.sh
    ./src/installer/system.sh
    ./src/installer/desktop.sh
    ./src/installer/stack.sh
    ./src/installer/apps.sh
    ./src/installer/cleaner.sh
    ./configs/alacritty/root.prompt
    ./configs/alacritty/user.prompt
    ./configs/bspwm/resize
    ./configs/bspwm/rules
    ./configs/bspwm/scratchpad
    ./configs/bspwm/swap
    ./configs/dunst/hook
    ./configs/polybar/scripts/*
    ./configs/rofi/launch
    ./configs/xsecurelock/hook
    ./build.sh
    ./test.sh
  )

  roots+=($(find ./src/tools -mindepth 2 -maxdepth 2 -type f -name 'main.sh')) ||
    abort ERROR 'Unable to list tools directories.'

  local root=''
  for root in "${roots[@]}"; do
    local files=''
    files=$(traverse_files "${root}" | sort -u) ||
      abort ERROR "Unable to traverse files in execution path of ${tool}."
    
    local all_funcs=''

    local file=''
    while read -r file; do
      local funcs=''
      funcs=$(grep '.*( *) *{.*' "${file}" | cut -d '(' -f 1)

      if [[ $? -gt 1 ]]; then
        abort ERROR 'Unable to read function declarations.'
      fi

      all_funcs+="${funcs}"$'\n'
    done <<< "${files}"

    local func=''
    while read -r func; do
      # Skip empty lines
      if [[ -z "${func}" ]] || [[ "${func}" =~ '^ *$' ]]; then
        continue
      fi

      local occurrences=0
      occurrences=$(echo "${all_funcs}" | grep -w "${func}" | wc -l)
      
      if [[ $? -gt 1 ]]; then
        abort ERROR 'Unable to iterate through function declarations.'
      fi

      if [[ ${occurrences} -gt 1 ]]; then
        log ERROR "[FAILED] No func overriden test: ${root}, ${func} [${occurrences}]."
        return 1
      fi
    done <<< "${all_funcs}"

    log INFO "[PASSED] No func overriden test: ${root}."
  done
}

test_no_shell_files &&
  test_no_func_overriden &&
  log INFO 'All test assertions have been passed.' ||
  abort ERROR 'Some tests have been failed to pass.'
