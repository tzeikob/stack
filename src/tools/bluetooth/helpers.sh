#!/bin/bash

source /opt/stack/commons/input.sh
source /opt/stack/commons/logger.sh
source /opt/stack/commons/math.sh
source /opt/stack/commons/validators.sh

# Returns all the available controllers.
# Outputs:
#  A json array of controller objects.
find_controllers () {
  bluetoothctl list | jc --bluetoothctl || return 1
}

# Returns the controller with the given address.
# If no address is given the default controller
# will be returned.
# Arguments:
#  address: the address of a controller
# Outputs:
#  A json object of a controller.
find_controller () {
  local address="${1}"

  local controller=''

  if is_empty "${address}"; then
    controller="$(bluetoothctl show)" || return 1
  else
    controller="$(bluetoothctl show "${address}")" || return 1
  fi

  echo "${controller}" | jc --bluetoothctl || return 1
}

# Returns all the available devices filtered by the
# optionally given status.
# Arguments:
#  status: paired, connected or trusted
# Outputs:
#  A json array of device objects.
find_devices () {
  local status="${1^}"

  local devices=''

  if is_empty "${status}"; then
    devices="$(bluetoothctl devices)" || return 1
  else
    devices="$(bluetoothctl devices "${status}")" || return 1
  fi

  echo "${devices}" | jc --bluetoothctl || return 1
}

# Returns the device with the given address.
# Arguments:
#  address: the address of a device
# Outputs:
#  A json object of a device.
find_device () {
  local address="${1}"

  bluetoothctl info "${address}" | jc --bluetoothctl || return 1
}

# Checks if the default controller is on scanning mode
# Returns:
#  0 if scanning is on otherwise 1.
is_scanning () {
  local mode=''
  mode="$(find_controller | jq -cer '.[0]|.discovering')" || return 1

  if is_yes "${mode}"; then
    return 0
  else
    return 1
  fi
}

# An inverse version of is_scanning.
is_not_scanning () {
  is_scanning && return 1 || return 0
}

# Shows a menu asking the user to select a controller.
# Outputs:
#  A menu of controllers.
pick_controller () {
  local query='{key: .address, value: "\(.address) [\(.name)]"}'
  query="[.[]|${query}]"

  local controllers=''
  controllers="$(find_controllers | jq -cer "${query}")" || return 1

  local len=0
  len=$(echo "${controllers}" | jq -cer 'length') || return 1

  if is_true "${len} = 0"; then
    log 'No controllers have found.'
    return 2
  fi
  
  pick_one 'Select controller address:' "${controllers}" vertical || return $?
}

# Shows a menu asking the user to select a device.
# Outputs:
#  A menu of devices.
pick_device () {
  local query='{key: .address, value: "\(.address) [\(.name)]"}'
  query="[.[]|${query}]"

  local devices=''
  devices="$(find_devices | jq -cer "${query}")" || return 1

  local len=0
  len=$(echo "${devices}" | jq -cer 'length') || return 1

  if is_true "${len} = 0"; then
    log 'No devices have found.'
    return 2
  fi
  
  pick_one 'Select device address:' "${devices}" vertical || return $?
}

# Kills any running bluetooth scanning proccesses.
kill_scanning_proccesses () {
  local query='.command|test("^bluetoothctl scan on")'
  query=".[]|select(${query})|.pid"

  local pids=''
  pids="$(ps aux | jc --ps | jq -cr "${query}")" || return 1

  # Clean any scanning processes one by one
  if is_not_empty "${pids}"; then
    local pid=''
    while read -r pid; do
      kill "${pid}"
    done <<< "${pids}"
  fi
}

# Checks if the given status is valid.
# Arguments:
#  status: a bluetooth device status
# Returns:
#  0 if status is valid otherwise 1.
is_valid_status () {
  local status="${1}"

  if not_match "${status}" '^(paired|connected|trusted|bonded)$'; then
    return 1
  fi

  return 0
}

# An inverse version of is_valid_status.
is_not_valid_status () {
  is_valid_status "${1}" && return 1 || return 0
}

