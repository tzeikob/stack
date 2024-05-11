#!/bin/bash

set -Eeo pipefail

source /opt/stack/commons/logger.sh
source /opt/stack/commons/validators.sh

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

# Resolves the given installation task script by addressing
# some extra fake post execution logs to pretent completion.
# Arguments:
#  task_name: the name of the task script
#  total_ops: the total max number of log lines the task is expected to print
# Outputs:
#  Fake log lines.
resolve () {
  local task_name="${1}"
  local total_ops="${2}"

  # Read the current progress as the number of log lines
  local lines=0
  lines=$(cat "/var/log/stack/${task_name}.log" | wc -l) ||
    abort ERROR "Unable to read the current ${task_name} log lines."

  # Fill the log file with fake lines to trick tqdm bar on completion
  if [[ ${lines} -lt ${total_ops} ]]; then
    local lines_to_append=0
    lines_to_append=$((total_ops - lines))

    while [[ ${lines_to_append} -gt 0 ]]; do
      echo '~'
      sleep 0.15
      lines_to_append=$((lines_to_append - 1))
    done
  fi

  return 0
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
