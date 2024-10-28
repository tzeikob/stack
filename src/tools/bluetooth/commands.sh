#!/bin/bash

source src/commons/process.sh
source src/commons/auth.sh
source src/commons/error.sh
source src/commons/logger.sh
source src/commons/math.sh
source src/commons/validators.sh
source src/tools/bluetooth/helpers.sh

# Shows the current status of bluetooth service
# and connected devices.
# Outputs:
#  A long list of bluetooth data.
show_status () {
  local space=15

  local query='.[] | select(.unit == ."bluetooth.service") | .active | lbl("Active")'

  systemctl  -a | jc --systemctl | jq -cer --arg SPC ${space} "${query}" || return 1

  local query=''
  query+='\(.name         | lbln("Controller"))'
  query+='\(.alias        | lbln("Alias"))'
  query+='\(.address      | lbln("Address"))'
  query+='\(.powered      | lbln("Powered"))'
  query+='\(.discovering  | lbln("Scanning"))'
  query+='\(.pairable     | lbln("Pairable"))'
  query+='\(.discoverable | lbl("Discoverable"))'
  
  find_controller | jq -cer --arg SPC ${space} ".[0] | \"${query}\""
  
  if has_failed; then
    echo '""' | jq -cer --arg SPC ${space} 'lbl("Controller")'
  fi

  local query=''
  query+='if . | length > 0 then .[] | .address else "" end'

  local devices=''
  devices="$(find_devices connected | jq -cer "${query}")" || return 1

  if is_empty "${devices}"; then
    return 0
  fi

  local query=''
  query+='\(.name    | lbln("Device"))'
  query+='\(.address | lbln("Address"))'
  query+='\(.icon    | lbl("Type"))'
  query="[.[] | \"${query}\"] | join(\"\n\")"

  local device=''
  while read -r device; do
    echo
    find_device "${device}" | jq -cer --arg SPC ${space} "${query}" || return 1
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
  query+='\(.name       | lbln("Name"))'
  query+='\(.is_default | olbln("Default"))'
  query+='\(.address    | lbl("Address"))'
  query="[.[] | \"${query}\"] | join(\"\n\n\")"

  echo "${controllers}" | jq -cer --arg SPC 10 "${query}" || return 1
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
  query+='\(.name    | lbln("Name"))'
  query+='\(.address | lbl("Address"))'
  query="[.[] | \"${query}\"] | join(\"\n\n\")"

  echo "${devices}" | jq -cer --arg SPC 10 "${query}" || return 1
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
  query+='\(.name                 | lbln("Name"))'
  query+='\(.manufacturer         | olbln("Manufacturer"))'
  query+='\(.address              | lbln("Address"))'
  query+='\(.is_public            | olbln("Public"))'
  query+='\(.alias                | lbln("Alias"))'
  query+='\(.powered              | lbln("Powered"))'
  query+='\(.discovering          | lbln("Discovering"))'
  query+='\(.pairable             | lbln("Pairable"))'
  query+='\(.discoverable         | lbln("Discoverable"))'
  query+='\(.discoverable_timeout | lbln("Timeout"))'
  query+='\(.modalias             | olbln("Modalias"))'
  query+='\(.class                | lbl("Class"))'
  
  echo "${controller}" | jq -cer --arg SPC 15 ".[0] | \"${query}\"" || return 1
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
  query+='\(.name           | lbln("Name"))'
  query+='\(.address        | lbln("Address"))'
  query+='\(.alias          | lbln("Alias"))'
  query+='\(.icon           | lbln("Icon"))'
  query+='\(.is_public      | olbln("Public"))'
  query+='\(.rssi           | olbln("RSSI"))'
  query+='\(.txpower        | olbln("Power"))'
  query+='\(.connected      | lbln("Connected"))'
  query+='\(.paired         | lbln("Paired"))'
  query+='\(.bonded         | lbln("Bonded"))'
  query+='\(.trusted        | lbln("Trusted"))'
  query+='\(.blocked        | lbln("Blocked"))'
  query+='\(.legacy_pairing | lbln("Legacy"))'
  query+='\(.modalias       | olbln("Modalias"))'
  query+='\(.class          | lbl("Class"))'
  
  echo "${device}" | jq -cer --arg SPC 12 ".[0] | \"${query}\"" || return 1
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

  find_controller 1> /dev/null
  
  if has_failed; then
    log 'Unable to find default controller.'
    return 2
  fi

  bluetoothctl power "${mode}" 1> /dev/null

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

  find_controller 1> /dev/null
  
  if has_failed; then
    log 'Unable to find default controller.'
    return 2
  fi

  # Kill any running scanning proccesses
  kill_scanning_proccesses || return 1
  
  if is_on "${mode}"; then
    bluetoothctl scan on 1> /dev/null &

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

  find_controller 1> /dev/null
  
  if has_failed; then
    log 'Unable to find default controller.'
    return 2
  fi

  bluetoothctl discoverable "${mode}" 1> /dev/null

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

  find_controller 1> /dev/null

  if has_failed; then
    log 'Unable to find default controller.'
    return 2
  fi

  bluetoothctl pairable "${mode}" 1> /dev/null

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

  bluetoothctl pair "${address}" 1> /dev/null &&
  bluetoothctl trust "${address}" 1> /dev/null &&
  bluetoothctl connect "${address}" 1> /dev/null

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

  bluetoothctl disconnect "${address}" 1> /dev/null

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

  bluetoothctl remove "${address}" 1> /dev/null

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
