#!/bin/bash

set -o pipefail

source /opt/stack/commons/utils.sh

CONFIG_HOME="${HOME}/.config/stack"
SECURITY_SETTINGS="${CONFIG_HOME}/security.json"

# Kills any proccesses of possibly
# running screen locker instances.
kill_screen_locker () {
  local query='.command|test("^xautolock")'
  query=".[]|select(${query})|.pid"
  
  local pids=''
  pids="$(ps aux | jc --ps | jq -cr "${query}")" || return 1

  # Kill processes one by one
  if is_not_empty "${pids}"; then
    local pid=''
    while read -r pid; do
      kill "${pid}"
    done <<< "${pids}"
  fi
}

# Stores the screen locker interval into
# the settings file.
# Arguments:
#  interval: the interval time in mins
save_screen_locker_to_settings () {
  local interval="${1}"

  local settings='{}'
  local object="{\"interval\": ${interval}}"

  if file_exists "${SECURITY_SETTINGS}"; then
    settings="$(jq -e ".screen_locker = ${object} " "${SECURITY_SETTINGS}")" || return 1
  else
    settings="$(echo "{\"screen_locker\": ${object}}" | jq -e '.')" || return 1
  fi

  mkdir -p "${CONFIG_HOME}"
  echo "${settings}" > "${SECURITY_SETTINGS}"
}

# Checks if the screen is locked.
# Outputs:
#  true if screen is locked otherwise false.
is_screen_locked () {
  local query=''
  query+='[.[]|select(.command|test("xsecurelock.*"))]'
  query+='|if length > 0 then "true" else "false" end'

  local is_locked=''
  is_locked="$(ps aux | grep -v 'jq' | jc --ps | jq -cr "${query}")" || return 1

  echo "${is_locked}"
}
