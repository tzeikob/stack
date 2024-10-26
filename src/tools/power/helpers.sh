#!/bin/bash

source src/commons/input.sh
source src/commons/logger.sh
source src/commons/validators.sh

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
  local query='if length > 0 then .[0] else "" end'

  local acpi_b=''
  acpi_b="$(acpi -b -i | jc --acpi | jq -cer "${query}")" || return 1

  if is_not_empty "${acpi_b}"; then
    acpi_b="$(echo "${acpi_b}" | jq -cer '.battery = true')" || return 1
  else
    echo ''
    return 0
  fi

  local battery_file='/sys/class/power_supply/BAT0'

  if file_exists "${battery_file}/current_now"; then
    local current_now=''
    current_now="$(< ${battery_file}/current_now)"

    acpi_b="$(echo "${acpi_b}" | jq -cer ".current_now = ${current_now}")" || return 1
  fi

  if file_exists "${battery_file}/charge_now"; then
    local charge_now=''
    charge_now="$(< ${battery_file}/charge_now)"
    
    acpi_b="$(echo "${acpi_b}" | jq -cer ".charge_now = ${charge_now}")" || return 1
  fi

  local config_file='/etc/tlp.d/00-main.conf'

  local start=''
  start="$(grep -E "^START_CHARGE_THRESH_BAT0=" "${config_file}" | cut -d '=' -f 2)"

  if is_not_empty "${start}"; then
    acpi_b="$(echo "${acpi_b}" | jq -cer ".start_charge_at = ${start}")" || return 1
  fi
    
  local stop=''
  stop="$(grep -E "^STOP_CHARGE_THRESH_BAT0=" "${config_file}" | cut -d '=' -f 2)"
    
  if is_not_empty "${stop}"; then
    acpi_b="$(echo "${acpi_b}" | jq -cer ".stop_charge_at = ${stop}")" || return 1
  fi

  echo "${acpi_b}"
}

# Returns various login power settings of the system.
# Outputs:
#  A json object of login power settings.
find_login_power_settings () {
  local settings=''

  settings="$(loginctl show-session | awk '{
    match($0,/(.*)=(.*)/,a)

    if (a[1] == "HandlePowerKey") {
      a[1]="on_power"
    } else if (a[1] == "HandleRebootKey") {
      a[1]="on_reboot"
    } else if (a[1] == "HandleSuspendKey") {
      a[1]="on_suspend"
    } else if (a[1] == "HandleHibernateKey") {
      a[1]="on_hibernate"
    } else if (a[1] == "HandleLidSwitch") {
      a[1]="on_lid_down"
    } else if (a[1] == "HandleLidSwitchDocked") {
      a[1]="on_docked"
    } else if (a[1] == "IdleAction") {
      a[1]="on_idle"
    } else if (a[1] == "Docked") {
      a[1]="docked"
    } else if (a[1] == "LidClosed") {
      a[1]="lid_down"
    } else {
      next
    }

    frm = "\"%s\": \"%s\","
    printf frm, a[1], a[2]
  }')" || return 1

  # Remove last comma
  settings="${settings:+${settings::-1}}"

  echo "{${settings}}"
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
