#!/bin/bash

source src/commons/validators.sh

CONFIG_HOME="${HOME}/.config/stack"
SECURITY_SETTINGS="${CONFIG_HOME}/security.json"

# Kills any proccesses of possibly
# running screen locker instances.
kill_screen_locker () {
  local query='.command | test("^xautolock")'

  query=".[] | select(${query}) | .pid"
  
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
# Returns:
#  0 if screen locker is up otherwise 1.
is_screen_locked () {
  local query='[.[] | select(.command | test("xsecurelock.*"))] | length > 0'

  ps aux | grep -v 'jq' | jc --ps | jq -cer "${query}" &> /dev/null
}

# Returns the password status of the system.
# Outputs:
#  A json object of password data.
find_password_status () {
  local status=''

  status="$(passwd -S | awk '{
    status = "protected"

    if ($2 == "L") {
      status = "locked"
    } else if ($2 == "NP") {
      status = "no password"
    }

    frm = "\"%s\": \"%s\","
    printf frm, "password", status
    printf frm, "last_changed", $3
  }')" || return 1

  # Remove last comma
  status="${status:+${status::-1}}"

  echo "{${status}}"
}

# Returns the faillock status.
# Outputs:
#  A json object of failock status.
find_faillock_status () {
  local status=''

  status="$(cat /etc/security/faillock.conf | awk '{
    key = ""

    if ($0 ~ /^deny =.*/) {
      key = "failed_attempts"
    } else if ($0 ~ /^unlock_time =.*/) {
      key = "unblock_time"
    } else if ($0 ~ /^fail_interval =.*/) {
      key = "fail_interval"
    }

    frm = "\"%s\": \"%s\","
    printf frm, key, $3
  }')" || return 1

  # Remove last comma
  status="${status:+${status::-1}}"

  echo "{${status}}"
}

# Returns the status of the locker.
# Outputs:
#  A json string of the locker status.
find_locker_status () {
  local locker_process=''

  locker_process="$(ps ax -o 'command' | jc --ps |
    jq '.[] | select(.command | test("^xautolock")) | .command')" || return 1
  
  if is_empty "${locker_process}"; then
    echo '"off"'
    return 0
  fi
  
  echo "${locker_process}" | awk '{
    match($0,/.* -time (.*) -corners.*/,a)
    print a[1]
  }' || return 1
}
