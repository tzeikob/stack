#!/bin/bash

set -o pipefail

source /opt/stack/commons/utils.sh

CONFIG_HOME="${HOME}/.config/stack"
POWER_SETTINGS="${CONFIG_HOME}/power.json"

# Finds the ac power adapter data.
# Outputs:
#  A json object of ac power data.
find_adapter () {
  acpi -a | jc --acpi | jq -cer '.[0]' || return 1
}

# Finds the battery power data.
# Outputs:
#  A json object of battery power data.
find_battery () {
  local query=''
  query+='if length > 0 then .[0] else "" end'

  acpi -b -i | jc --acpi | jq -cer "${query}" || return 1
}

# Shows a menu asking the user to select a power handler.
# Outputs:
#  A menu of power handlers.
pick_power_handler () {
  local handlers=''
  handlers+='{"key":"power", "value":"power"},'
  handlers+='{"key":"reboot", "value":"reboot"},'
  handlers+='{"key":"suspend", "value":"suspend"},'
  handlers+='{"key":"lid", "value":"lid"},'
  handlers+='{"key":"docked", "value":"docked"}'
  handlers="[${handlers}]"

  pick_one 'Select power handler:' "${handlers}" vertical || return $?
}

# Checks if the given power handler is a valid one.
# Arguments:
#  handler: the name of a power handler
# Returns:
#  0 if it is valid otherwise 1.
is_power_handler () {
  local handler="${1}"
  
  if not_match "${handler}" '^(power|reboot|suspend|lid|docked)$'; then
    return 1
  fi

  return 0
}

# An inverse version of is_power_handler.
is_not_power_handler () {
  is_power_handler "${1}" && return 1 || return 0
}

# Shows a menu asking the user to select a power action.
# Outputs:
#  A menu of power actions.
pick_power_action () {
  local actions=''
  actions+='{"key":"poweroff", "value":"poweroff"},'
  actions+='{"key":"reboot", "value":"reboot"},'
  actions+='{"key":"suspend", "value":"suspend"},'
  actions+='{"key":"ignore", "value":"ignore"}'
  actions="[${actions}]"

  pick_one 'Select an action:' "${actions}" vertical || return $?
}

# Checks if the given power action is a valid one.
# Arguments:
#  action: the name of a power action
# Returns:
#  0 if it is valid otherwise 1.
is_power_action () {
  local action="${1}"
  
  if not_match "${action}" '^(poweroff|reboot|suspend|ignore)$'; then
    return 1
  fi

  return 0
}

# An inverse version of is_power_action.
is_not_power_action () {
  is_power_action "${1}" && return 1 || return 0
}

# Resolves the corresponding logind config option
# for the given power handler.
# Arguments:
#  handler: the name of a power handler
# Outputs:
#  A logind config option.
convert_handler_to_option () {
  local handler="${1}"

  local option=''

  case "${handler}" in
    'power') option='HandlePowerKey';;
    'reboot') option='HandleRebootKey';;
    'suspend') option='HandleSuspendKey';;
    'lid') option='HandleLidSwitch';;
    'docked') option='HandleLidSwitchDocked';;
    *)
      log 'Invalid or unknown power handler.'
      return 2;;
  esac

  echo "${option}"
}

# Saves the interval time of the screen saver into settings.
# Arguments:
#  interval: the interval time in mins or 0
save_screen_saver_to_settings () {
  local interval="${1}"

  local settings='{}'
  local screensaver="{\"interval\": ${interval}}"

  if file_exists "${POWER_SETTINGS}"; then
    settings="$(jq -e ".screensaver = ${screensaver} " "${POWER_SETTINGS}")" || return 1
  else
    settings="$(echo "{\"screensaver\": ${screensaver}}" | jq -e '.')" || return 1
  fi

  mkdir -p "${CONFIG_HOME}"
  echo "${settings}" > "${POWER_SETTINGS}"
}

