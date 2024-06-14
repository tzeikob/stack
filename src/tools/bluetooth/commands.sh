#!/bin/bash

set -o pipefail

source /opt/stack/commons/process.sh
source /opt/stack/commons/auth.sh
source /opt/stack/commons/error.sh
source /opt/stack/commons/logger.sh
source /opt/stack/commons/math.sh
source /opt/stack/commons/validators.sh
source /opt/stack/tools/bluetooth/helpers.sh

# Shows the current status of bluetooth service
# and connected devices.
# Outputs:
#  A long list of bluetooth data.
show_status () {
  systemctl status --lines 0 --no-pager bluetooth.service | awk '{
    if ($0 ~ / *Active/) {
      l = "Service"
      v = $2" "$3
    } else l = ""

    if (l) printf "%-14s %s\n",l":",v
  }' || return 1

  local query=''
  query+='Controller:    \(.name) [\(.alias)]\n'
  query+='Address:       \(.address)\n'
  query+='Powered:       \(.powered)\n'
  query+='Scanning:      \(.discovering)\n'
  query+='Pairable:      \(.pairable)\n'
  query+='Discoverable:  \(.discoverable)'
  
  find_controller | jq -cer ".[0]|\"${query}\""
  
  if has_failed; then
    echo 'Controller:    none'
  fi

  local query=''
  query+='if .|length > 0 then .[]|.address else "" end'

  local devices=''
  devices="$(find_devices connected | jq -cer "${query}")" || return 1

  if is_empty "${devices}"; then
    return 0
  fi

  local query=''
  query+='Device:        \(.name)\n'
  query+='Address:       \(.address)\n'
  query+='Type:          \(.icon)'
  query="[.[]|\"${query}\"]|join(\"\n\")"

  local device=''
  while read -r device; do
    echo
    find_device "${device}" | jq -cer "${query}" || return 1
  done <<< "${devices}"
}

# Shows the logs of the bluetooth service.
# Outputs:
#  A long list of log messages.
show_logs () {
  systemctl status --no-pager bluetooth.service | tail -n +13 || return 1
}

# Shows the list of available controllers.
# Outputs:
#  A list of bluetooth controllers.
list_controllers () {
  local controllers=''
  controllers="$(find_controllers)" || return 1

  local len=0
  len="$(echo "${controllers}" | jq -cer 'length')" || return 1

  if is_true "${len} = 0"; then
    log 'No controllers have found.'
    return 0
  fi

  local query=''
  query+='Name:     \(.name)\n'
  query+='Address:  \(.address)'
  query+='\(if .is_default then "\nDefault:  \(.is_default)" else "" end)'
  query="[.[]|\"${query}\"]|join(\"\n\n\")"

  echo "${controllers}" | jq -cer "${query}" || return 1
}

# Shows the list of available devices filtered by
# the optionally given status.
# Arguments:
#  status: paired, connected or trusted
# Outputs:
#  A list of bluetooth devices.
list_devices () {
  local status="${1}"

  if is_given "${status}" && is_not_valid_status "${status}"; then
    log 'Invalid device status.'
    return 2
  fi

  local devices=''
  devices="$(find_devices "${status^}")" || return 1

  local len=0
  len="$(echo "${devices}" | jq -cer 'length')" || return 1

  if is_true "${len} = 0"; then
    log 'No available devices have found.'
    return 0
  fi

  local query=''
  query+='Name:     \(.name)\n'
  query+='Address:  \(.address)'
  query="[.[]|\"${query}\"]|join(\"\n\n\")"

  echo "${devices}" | jq -cer "${query}" || return 1
}

# Shows the data of the controller with the given
# address.
# Arguments:
#  address: the address of a controller
# Outputs:
#  A list of controller data.
show_controller () {
  local address="${1}"

  if is_not_given "${address}"; then
    on_script_mode &&
      log 'Missing controller address.' && return 2

    pick_controller || return $?
    is_empty "${REPLY}" && log 'Controller address required.' && return 2
    address="${REPLY}"
  fi

  local controller=''
  controller="$(find_controller "${address}")"

  if has_failed; then
    log "Controller ${address} not found."
    return 2
  fi

  local query=''
  query+='Name:          \(.name)\n'
  query+='Address:       \(.address)\n'
  query+='\(.is_public|if . then "Public:        \(.)\n" else "" end)'
  query+='Alias:         \(.alias)\n'
  query+='Powered:       \(.powered)\n'
  query+='Discovering:   \(.discovering)\n'
  query+='Pairable:      \(.pairable)\n'
  query+='Discoverable:  \(.discoverable)\n'
  query+='Timeout:       \(.discoverable_timeout)\n'
  query+='Modalias:      \(.modalias)\n'
  query+='Class:         \(.class)'
  query+='\(.uuids|if . then "\nUUID:          \(.|join("\n               "))" else "" end)'
  
  echo "${controller}" | jq -cer ".[0]|\"${query}\"" || return 1
}

# Shows the data of the device with the given
# address.
# Arguments:
#  address: the address of a device
# Outputs:
#  A list of device data.
show_device () {
  local address="${1}"

  if is_not_given "${address}"; then
    on_script_mode &&
      log 'Missing device address.' && return 2
  
    pick_device || return $?
    is_empty "${REPLY}" && log 'Device address required.' && return 2
    address="${REPLY}"
  fi

  local device=''
  device="$(find_device "${address}")"

  if has_failed; then
    log "Device ${address} not found."
    return 2
  fi

  local query=''
  query+='Name:       \(.name)\n'
  query+='Address:    \(.address)\n'
  query+='Alias:      \(.alias)\n'
  query+='Icon:       \(.icon)\n'
  query+='\(.is_public|if . then "Public:     \(.)\n" else "" end)'
  query+='\(.rssi|if . then "RSSI:       \(.)\n" else "" end)'
  query+='\(.txpower|if . then "Power:      \(.)\n" else "" end)'
  query+='Connected:  \(.connected)\n'
  query+='Paired:     \(.paired)\n'
  query+='Bonded:     \(.bonded)\n'
  query+='Trusted:    \(.trusted)\n'
  query+='Blocked:    \(.blocked)\n'
  query+='Legacy:     \(.legacy_pairing)\n'
  query+='\(.modalias|if . then "Modalias:   \(.)\n" else "" end)'
  query+='Class:      \(.class)'
  query+='\(.uuids|if . then "\nUUID:       \(.|join("\n            "))" else "" end)'
  
  echo "${device}" | jq -cer ".[0]|\"${query}\"" || return 1
}

# Sets the default controller to the controller
# with the given address.
# Arguments:
#  address: the address of a controller
set_controller () {
  local address="${1}"

  if is_not_given "${address}"; then
    on_script_mode &&
      log 'Missing controller address.' && return 2

    pick_controller || return $?
    is_empty "${REPLY}" && log 'Controller address required.' && return 2
    address="${REPLY}"
  fi

  local controller=''
  controller="$(find_controller "${address}")"

  if has_failed; then
    log "Controller ${address} not found."
    return 2
  fi

  bluetoothctl select "${address}"

  if has_failed; then
    log 'Failed to set default controller.'
    return 2
  fi

  log "Default controller set to ${address}."
}

# Sets the default controller power to on/off.
# Arguments:
#  mode: on or off
set_power () {
  local mode="${1}"

  if is_not_given "${mode}"; then
    log 'Missing power mode.'
    return 2
  elif is_not_toggle "${mode}"; then
    log 'Invalid power mode.'
    return 2
  fi

  find_controller &> /dev/null
  
  if has_failed; then
    log 'Unable to find default controller.'
    return 2
  fi

  bluetoothctl power "${mode}" &> /dev/null

  if has_failed; then
    log "Failed to set power mode to ${mode}."
    return 2
  fi

  log "Power mode set to ${mode}."
}

# Sets scanning mode to on or off.
# Arguments:
#  mode: on or off
set_scan () {
  local mode="${1}"

  if is_not_given "${mode}"; then
    log 'Missing scanning mode.'
    return 2
  elif is_not_toggle "${mode}"; then
    log 'Invalid scanning mode.'
    return 2
  fi

  find_controller &> /dev/null
  
  if has_failed; then
    log 'Unable to find default controller.'
    return 2
  fi

  # Kill any running scanning proccesses
  kill_scanning_proccesses || return 1
  
  if is_on "${mode}"; then
    bluetoothctl scan on &> /dev/null &

    is_not_scanning &&
      log 'Failed to enable scanning mode.' && return 2
  else
    is_scanning &&
      log 'Failed to disable scanning mode.' && return 2
  fi

  log "Scanning mode set to ${mode}."
}

# Sets the default controller discoverable mode to on/off.
# Arguments:
#  mode: on or off
set_discoverable () {
  local mode="${1}"

  if is_not_given "${mode}"; then
    log 'No discoverable mode given.'
    return 2
  elif is_not_toggle "${mode}"; then
    log 'Invalid discoverable mode.'
    return 2
  fi

  find_controller &> /dev/null
  
  if has_failed; then
    log 'Unable to find default controller.'
    return 2
  fi

  bluetoothctl discoverable "${mode}" &> /dev/null

  if has_failed; then
    log "Failed to set discoverable mode to ${mode}."
    return 2
  fi

  log "Discoverable mode set to ${mode}."
}

# Sets the default controller pairable mode to on/off.
# Arguments:
#  mode: on or off
set_pairable () {
  local mode="${1}"

  if is_not_given "${mode}"; then
    log 'No pairable mode given.'
    return 2
  elif is_not_toggle "${mode}"; then
    log 'Invalid pairable mode.'
    return 2
  fi

  find_controller &> /dev/null

  if has_failed; then
    log 'Unable to find default controller.'
    return 2
  fi

  bluetoothctl pairable "${mode}" &> /dev/null

  if has_failed; then
    log "Failed to set pairable mode to ${mode}."
    return 2
  fi

  log "Pairable mode set to ${mode}."
}

# Connects to the device with the given address.
# Arguments:
#  address: the address of a device
connect_device () {
  local address="${1}"

  if is_not_given "${address}"; then
    on_script_mode &&
      log 'Missing device address.' && return 2
  
    pick_device || return $?
    is_empty "${REPLY}" && log 'Device address required.' && return 2
    address="${REPLY}"
  fi

  local device=''
  device="$(find_device "${address}")"

  if has_failed; then
    log "Device ${address} not found."
    return 2
  fi

  bluetoothctl pair "${address}" &> /dev/null &&
  bluetoothctl trust "${address}" &> /dev/null &&
  bluetoothctl connect "${address}" &> /dev/null

  if has_failed; then
    log "Failed to connect device ${address}."
    return 2
  fi

  log "Device ${address} has been connected."
}

# Disconnects the device with the given address.
# Arguments:
#  address: the address of a device
disconnect_device () {
  local address="${1}"

  if is_not_given "${address}"; then
    on_script_mode &&
      log 'Missing device address.' && return 2
  
    pick_device || return $?
    is_empty "${REPLY}" && log 'Device address required.' && return 2
    address="${REPLY}"
  fi

  local device=''
  device="$(find_device "${address}")"

  if has_failed; then
    log "Device ${address} not found."
    return 2
  fi

  bluetoothctl disconnect "${address}" &> /dev/null

  if has_failed; then
    log "Failed to disconnect device ${address}."
    return 2
  fi

  log "Device ${address} has been disconnected."
}

# Removes the device with the given address.
# Arguments:
#  address: the address of a device
remove_device () {
  local address="${1}"

  if is_not_given "${address}"; then
    on_script_mode &&
      log 'Missing device address.' && return 2
  
    pick_device || return $?
    is_empty "${REPLY}" && log 'Device address required.' && return 2
    address="${REPLY}"
  fi

  local device=''
  device="$(find_device "${address}")"

  if has_failed; then
    log "Device ${address} not found."
    return 2
  fi

  bluetoothctl remove "${address}" &> /dev/null

  if has_failed; then
    log "Failed to remove device ${address}."
    return 2
  fi

  log "Device ${address} has been removed."
}

# Restarts the bluetooth service.
restart_bluetooth () {
  authenticate_user || return $?

  rfkill block bluetooth &&
  rfkill unblock bluetooth &&
  sudo modprobe -r btusb &&
  sudo modprobe -r btintel &&
  sudo modprobe btintel &&
  sudo modprobe btusb &&
  sudo systemctl restart bluetooth.service

  if has_failed; then
    log 'Failed to restart the bluetooth service.'
    return 2
  fi

  log 'Bluetooth service has been restarted.'
}

