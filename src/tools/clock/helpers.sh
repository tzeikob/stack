#!/bin/bash

source src/commons/input.sh
source src/commons/error.sh
source src/commons/logger.sh
source src/commons/math.sh
source src/commons/validators.sh

CONFIG_HOME="${HOME}/.config/stack"
CLOCK_SETTINGS="${CONFIG_HOME}/clock.json"

# Shows a menu asking the user to select a timezone.
# Arguments:
#  prompt: a prompt text line
# Outputs:
#  A menu of timezones.
pick_timezone () {
  local prompt="${1}"
  
  local timezones=''
  timezones="$(timedatectl list-timezones | awk '{
    print "{\"key\":\""$0"\",\"value\":\""$0"\"},"
  }')" || return 1

  # Remove the extra comma after the last array element
  timezones="${timezones:+${timezones::-1}}"

  timezones="[${timezones}]"

  local len=0
  len=$(echo "${timezones}" | jq -cer 'length') || return 1

  if is_true "${len} = 0"; then
    log 'No timezones have found.'
    return 2
  fi
  
  pick_one "${prompt}" "${timezones}" vertical || return $?
}

# Checks if the given timezone name is valid.
# Arguments:
#  name: the name of a timezone
# Returns:
#  0 if timezone is valid otherwise 1.
is_timezone () {
  local name="${1}"
  
  timedatectl list-timezones | grep -qw "${name}"
}

# An inverse version of is_timezone.
is_not_timezone () {
  ! is_timezone "${1}"
}

# Checks if the given mode is a valid RTC mode.
# Arguments:
#  mode: an rtc mode value
# Returns:
#  0 if mode is valid otherwise 1.
is_rtc_mode () {
  local mode="${1}"

  match "${mode}" '^(local|utc)$'
}

# An inverse version of is_rtc_mode.
is_not_rtc_mode () {
  ! is_rtc_mode "${1}"
}

# Checks if the given value is a valid time precision.
# Argurments:
#  value: mins, secs or nanos
# Returns:
#  0 if value is valid otherwise 1.
is_time_precision () {
  local value="${1}"

  match "${value}" '^(mins|secs|nanos)$'
}

# An inversed alias of is_time_precision.
is_not_time_precision () {
  ! is_time_precision "${1}"
}

# Checks if the given value is a valid time mode.
# Argurments:
#  value: 12h or 24h
# Returns:
#  0 if value is valid otherwise 1.
is_time_mode () {
  local value="${1}"

  match "${value}" '^(12h|24h)$'
}

# An inversed alias of is_time_mode.
is_not_time_mode () {
  ! is_time_mode "${1}"
}

# Checks if the NTP service is active or not.
is_ntp_active () {
  local ntp_status=''
  ntp_status="$(timedatectl | jc --timedatectl | jq -cer '.ntp_service')" || return 1

  equals "${ntp_status}" 'active'
}

# An inverse alias of is_ntp_active.
is_ntp_inactive () {
  ! is_ntp_active
}

# Saves the time format into settings.
# Arguments:
#  mode:      12h or 24h
#  precision: mins, secs or nanos
save_time_format_to_settings () {
  local mode="${1}"
  local precision="${2}"

  local settings='{}'

  if file_exists "${CLOCK_SETTINGS}"; then
    local query=''
    query+=".time_mode = \"${mode}\" | .time_precision = \"${precision}\""
    
    settings="$(jq -e "${query}" "${CLOCK_SETTINGS}")" || return 1
  else
    local object="{\"time_mode\": \"${mode}\", \"time_precision\": \"${precision}\"}"
    
    settings="$(echo "${object}" | jq -e '.')" || return 1
  fi

  mkdir -p "${CONFIG_HOME}"
  echo "${settings}" > "${CLOCK_SETTINGS}"
}

# Saves the date format into settings and the
# corresponding polybar date module.
# Arguments:
#  pattern: a date format
save_date_format_to_settings () {
  local pattern="${1}"

  local settings='{}'

  if file_exists "${CLOCK_SETTINGS}"; then
    local query=".date_pattern = \"${pattern}\""
    
    settings="$(jq -e "${query}" "${CLOCK_SETTINGS}")" || return 1
  else
    local object="{\"date_pattern\": \"${pattern}\"}"
    
    settings="$(echo "${object}" | jq -e '.')" || return 1
  fi

  mkdir -p "${CONFIG_HOME}"
  echo "${settings}" > "${CLOCK_SETTINGS}"

  # Update the format in the corresponding polybar date module
  sed -i "s;^date =.*;date = ${pattern};" "${HOME}/.config/polybar/modules.ini"
}
