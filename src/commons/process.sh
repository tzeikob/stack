#!/bin/bash

source src/commons/validators.sh

# Checks if any processes matching the given command
# pattern are running.
# Arguments:
#  re: any regular expression
# Returns:
#  0 if any processes are running otherwise 1.
is_process_up () {
  local re="${1}"
  
  local query=".command|test(\"${re}\")"
  query=".[]|select(${query})"
  
  ps aux | grep -v 'jq' | jc --ps | jq -cer "${query}" &> /dev/null || return 1
}

# An inverse version of is_process_up.
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

# Checks if we run on script mode or not by checking
# if the flag ON_SCRIPT_MODE has been set indicating
# the call was made by a not human.
# Returns:
#  0 if run on script mode otherwise 1.
on_script_mode () {
  if is_empty "${ON_SCRIPT_MODE}"; then
    return 1
  fi

  if not_equals "${ON_SCRIPT_MODE,,}" 'true'; then
    return 1
  fi

  return 0
}

# An inverse version of on_script_mode.
not_on_script_mode () {
  on_script_mode && return 1 || return 0
}

# An alias version of not_on_script_mode.
on_user_mode () {
  not_on_script_mode && return 0 || return 1
}

# Checks if the script is running on quiet mode by
# checking if the global quiet variable has set.
# Returns:
#  0 if run on quiet mode otherwise 1.
on_quiet_mode () {
  if is_empty "${ON_QUIET_MODE}"; then
    return 1
  fi

  if not_equals "${ON_QUIET_MODE,,}" 'true'; then
    return 1
  fi

  return 0
}

# An inverse version of on_quiet_mode.
not_on_quiet_mode () {
  on_quiet_mode && return 1 || return 0
}

# An alias version of not_on_quiet_mode.
on_loud_mode () {
  not_on_quiet_mode && return 0 || return 1
}
