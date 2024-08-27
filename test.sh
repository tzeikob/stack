#!/bin/bash

set -o pipefail

source src/commons/logger.sh
source src/commons/error.sh
source src/commons/math.sh
source src/commons/validators.sh

# Iterate recursively starting from the given file path
# all the way down following every source file.
# Arguments:
#  root: the root entry file of an execution path
# Outputs:
#  All the source file paths loaded in the execution path.
traverse_files () {
  local root="${1}"

  if is_empty "${root}" || match "${root}" '^ *$'; then
    echo ''
  else
    # Collect all files sourced in the current root file
    local files=''
    files=$(grep -e '^source .*' "${root}" | cut -d ' ' -f 2)

    if [[ $? -gt 1 ]]; then
      return 1
    fi

    if is_not_empty "${files}" && not_match "${files}" '^ *$'; then
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
  count=$(find src -type f -not -name '*.sh' | wc -l) ||
    abort ERROR 'Unable to list source files.'

  if is_true "${count} > 0"; then
    log ERROR '[FAILED] No shell files test.'
    return 1
  fi

  log INFO '[PASSED] No shell files test.'
}

# Asserts no func gets overriden on execution paths.
test_no_func_overriden () {
  local roots=(
    src/commons/*
    src/installer/*
    src/tools/**/main.sh
    airootfs/etc/pacman.d/scripts/*
    airootfs/home/user/.config/bspwm/resize
    airootfs/home/user/.config/bspwm/rules
    airootfs/home/user/.config/scratchpad
    airootfs/home/user/.config/swap
    airootfs/home/user/.config/dunst/hook
    airootfs/home/user/.config/polybar/scripts/*
    airootfs/home/user/.config/rofi/launch
    airootfs/home/user/.stackrc
    airootfs/usr/lib/systemd/system-sleep/locker
    install.sh
    build.sh
    upgrade.sh
    test.sh
  )

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
      if is_empty "${func}" || match "${func}" '^ *$'; then
        continue
      fi

      local occurrences=0
      occurrences=$(echo "${all_funcs}" | grep -w "${func}" | wc -l)
      
      if [[ $? -gt 1 ]]; then
        abort ERROR 'Unable to iterate through function declarations.'
      fi

      if is_true "${occurrences} > 1"; then
        log ERROR "[FAILED] No func overriden test: ${root}."
        log ERROR "[FAILED] No func overriden test: ${func} [${occurrences}]."
        return 1
      fi
    done <<< "${all_funcs}"

    log INFO "[PASSED] No func overriden test: ${root}."
  done
}

# Asserts no local variable declaration is followed by an
# error or abort handler given in the same line.
test_local_var_declarations () {
  local files=(install.sh build.sh upgrade.sh test.sh)
  files+=($(find src airootfs -type f)) ||
    abort ERROR 'Unable to list source files.'
  
  local file=''
  for file in "${files[@]}"; do
    local declarations=''
    declarations=$(grep -e '^ *local  *.*=.*' "${file}")

    if [[ $? -gt 1 ]]; then
      abort ERROR 'Unable to rertieve local variable declarations.'
    fi

    local declaration=''
    while read -r declaration; do
      # Skip empty lines
      if is_empty "${declaration}" || match "${declaration}" '^ *$'; then
        continue
      fi

      if match "${declaration}" '=\"?\$\(.*'; then
        log ERROR "[FAILED] Local var declarations test: ${file}."
        log ERROR "[FAILED] Local var declarations test: ${declaration}"
        return 1
      fi
    done <<< "${declarations}"
  done

  log INFO '[PASSED] Local var declarations test.'
}

test_no_shell_files &&
  test_no_func_overriden &&
  test_local_var_declarations &&
  log INFO 'All test assertions have been passed.' ||
  abort ERROR 'Some tests have been failed to pass.'
