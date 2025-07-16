#!/bin/bash

source src/commons/validators.sh
source src/commons/text.sh

# Checks if any processes matching the given command
# pattern are running.
# Arguments:
#  re: any regular expression
# Returns:
#  0 if any processes are running otherwise 1.
is_process_up () {
  local re="${1}"
  
  local query=".[]|select(.command|test(\"${re}\"))"
  
  ps aux | grep -v 'jq' | jc --ps | jq -cer "${query}" &> /dev/null
}

# An inverse version of is_process_up.
is_process_down () {
  ! is_process_up "${1}"
}

# Kills all the processes the command of which match
# the given regular expression.
# Arguments:
#  re: any regular expression
kill_process () {
  local re="${1}"

  pkill --full "${re}" 1> /dev/null

  sleep 1
}

# Prints a progress animation as long as the given
# process is still up and running, blocking the
# current thread unitl the given process resolves.
# Arguments:
#  pid:      the id of the running process
#  log_file: the log file the process is logging to
spin () {
  local pid="${1}"
  local log_file="${2}"

  local foreground=$(tput setaf 3)
  local reset_colors=$(tput sgr0)

  local icons=''
  local icons_length=${#icons}

  local i=0
  local previous_log='Please wait...'
  local previous_length=0

  while test -d /proc/"${pid}"; do
    local icon="${icons:i++%icons_length:1}"

    local log=''

    if file_exists "${log_file}"; then
      local last_log=''
      last_log="$(tail -n1 "${log_file}")"

      if is_not_empty "${last_log}" && match "${last_log}" '^(INFO|WARN|ERROR) '; then
        log="$(echo "${last_log}" | sed -E 's/^(INFO|WARN|ERROR) //' | trim)"
      fi
    fi

    if is_empty "${log}"; then
      log="${previous_log}"
    fi

    local message="${icon} ${log^}"

    local spaces=0
    spaces=$((${#message} - ${previous_length}))

    # Make sure previous longer lines not overlaping the current
    if [[ ${spaces} -lt 0 ]]; then
      printf "\r%s%${spaces}s" "${foreground}${message}${reset_colors}"
    else
      printf '\r%s' "${foreground}${message}${reset_colors}"
    fi

    previous_log="${log}"
    previous_length=${#message}

    sleep 0.12
  done

  wait ${pid}

  local exit_code=$?

  # Clear the log line
  tput cub $(tput cols)
  tput el

  return ${exit_code}
}

# Checks if we run on script mode or not by checking
# if the flag ON_SCRIPT_MODE has been set indicating
# the call was made by a not human.
# Returns:
#  0 if run on script mode otherwise 1.
on_script_mode () {
  if is_empty "${ON_SCRIPT_MODE}"; then
    return 1
  fi

  equals "${ON_SCRIPT_MODE,,}" 'true'
}

# An inverse version of on_script_mode.
not_on_script_mode () {
  ! on_script_mode
}

# An alias version of not_on_script_mode.
on_user_mode () {
  not_on_script_mode
}

# Checks if the script is running on quiet mode by
# checking if the global quiet variable has set.
# Returns:
#  0 if run on quiet mode otherwise 1.
on_quiet_mode () {
  if is_empty "${ON_QUIET_MODE}"; then
    return 1
  fi

  equals "${ON_QUIET_MODE,,}" 'true'
}

# An inverse version of on_quiet_mode.
not_on_quiet_mode () {
  ! on_quiet_mode
}

# An alias version of not_on_quiet_mode.
on_loud_mode () {
  not_on_quiet_mode
}
