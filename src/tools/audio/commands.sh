#!/bin/bash

set -o pipefail

source /opt/stack/commons/utils.sh
source /opt/stack/commons/logger.sh
source /opt/stack/commons/json.sh
source /opt/stack/commons/math.sh
source /opt/stack/tools/audio/helpers.sh

# Shows the current status of system's audio.
# Outputs:
#  A verbose list of text data.
show_status () {
  local query=''
  query+='Server:    \(.server_name)\n'
  query+='Sample:    \(.default_sample_specification)\n'
  query+='Channels:  \(.default_channel_map)'

  pactl --format=json info | jq -cer "(\"${query}\")" || return 1

  systemctl --user status --lines 0 --no-pager pipewire-pulse.service |
    awk '{
      if ($0 ~ / *Active/) {
        l = "Active"
        v = $2" "$3
      } else if ($0 ~ / *Main PID/) {
        l = "Process"
        v = $3" "$4
      } else l = ""

      if (l) printf "%-10s %s\n",l":",v
    }' || return 1

  local query=''
  query+='.[]|.properties'
  query+='|if ."device.nick" then ."device.nick"'
  query+=' else ."device.alias" end'
  query="[${query}]|join(\"\n           \")"

  echo -n 'Cards:     '
  find_cards | jq -cer "${query}" || return 1

  local sink=''
  sink="$(pactl get-default-sink)" || return 1

  local query='\n'
  query+='Output:    \(.properties|if ."device.nick" then ."device.nick" else ."device.alias" end)\n'
  query+='Port:      \(.active_port)\n'
  query+='Volume:    \(.volume|keys[0] as $k|.[$k].db|gsub("\\s+";"")) \(if .mute then "mute" else "" end)'

  query=".[]|select(.name == \"${sink}\")|select(.active_port)|\"${query}\""

  pactl --format=json list sinks | jq -cr "${query}" || return 1

  local source=''
  source="$(pactl get-default-source)" || return 1

  local query='\n'
  query+='Input:     \(.properties|if ."device.nick" then ."device.nick" else ."device.alias" end)\n'
  query+='Port:      \(.active_port)\n'
  query+='Volume:    \(.volume|keys[0] as $k|.[$k].db|gsub("\\s+";"")) \(if .mute then "mute" else "" end)'

  query=".[]|select(.name == \"${source}\")|select(.active_port)|\"${query}\""

  pactl --format=json list sources | jq -cr "${query}" || return 1
}

# Shows the logs of the audio service.
# Outputs:
#  A long list of log messages.
show_logs () {
  systemctl --user status --no-pager pipewire-pulse.service | tail -n +12 || return 1
}

# Shows the data of the card with identified by the
# given name.
# Arguments:
#  name: the name of an audio card
# Outputs:
#  A verbose list of text data.
show_card () {
  local name="${1}"

  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Missing the audio card name.' && return 2

    pick_card 'Select audio card name:' || return $?
    is_empty "${REPLY}" && log 'Audio card name is required.' && return 2
    name="${REPLY}"
  fi

  local card=''
  card="$(find_card "${name}")"

  if has_failed; then
    log "Audio card ${name} not found."
    return 2
  fi

  local query='("'
  query+='Model:     \(.properties|if ."device.nick" then ."device.nick" else ."device.alias" end)\n'
  query+='\(.properties."device.product.name"|if . then "Product:   \(.)\n" else "" end)'
  query+='\(.properties."device.vendor.name"|if . then "Vendor:    \(.)\n" else "" end)'
  query+='Name:      \(.name)\n'
  query+='Driver:    \(.driver)\n'
  query+='Bus:       \(.properties."device.bus" | ascii_upcase)\n'
  query+='\(.properties."api.alsa.use-acp"|if . then "ACP:       \(.)\n" else "" end)'
  query+='Profile:   \(.active_profile)")'

  echo "${card}" | jq -cer "${query}" || return 1

  local query=''
  query='.profiles|[keys[]]|join("\n           ")'

  echo
  echo -n 'Profiles:  '
  echo "${card}" | jq -cer "${query}" || return 1

  local query=''
  query='[.ports|to_entries[]|"\(.key) [\(.value.type)]"]|join("\n           ")'

  echo
  echo -n 'Ports:     '
  echo "${card}" | jq -cr "${query}" || return 1
}

# Restarts the audio services.
# Arguments:
#  none
restart () {
  log 'Restarting audio services...'

  systemctl --user restart pipewire.socket &&
    sleep 0.5 &&
    log 'Pipewire socket restarted.' &&
  systemctl --user restart pipewire.service &&
    sleep 0.5 &&
    log 'Pipewire service restarted.' &&
  systemctl --user restart pipewire-session-manager.service &&
    sleep 0.5 &&
  systemctl --user restart pipewire-media-session.service &&
    sleep 0.5 &&
  systemctl --user restart pipewire-pulse.socket &&
    sleep 0.5 &&
    log 'Pulse socket restarted.' &&
  systemctl --user restart pipewire-pulse.service &&
    sleep 0.5 &&
    log 'Pulse service restarted.'

  if has_failed; then
    log 'Failed to restart audio services.'
    return 2
  fi

  # Try to restart status bars
  desktop -qs init bars &> /dev/null

  log 'Audio services has been restarted.'
}

# Shows the list of all audio cards of the system.
# Arguments:
#  none
# Outputs:
#  The list of audio cards.
list_cards () {
  local cards=''
  cards="$(find_cards)" || return 1

  local len=0
  len="$(get_len "${cards}")" || return 1

  if is_true "${len} = 0"; then
    log 'No audio cards have found.'
    return 0
  fi

  local query=''
  query+='Model:  \(.properties|if ."device.nick" then ."device.nick" else ."device.alias" end)\n'
  query+='\(.properties."device.vendor.name"|if . then "Vendor: \(.)\n" else "" end)'
  query+='Name:   \(.name)'

  query="[.[]|\"${query}\"]|join(\"\n\n\")"

  echo "${cards}" | jq -cr "${query}" || return 1
}

# Shows a list of output or input audio modules.
# Arguments:
#  type: output or input
# Outputs:
#  The list of output or input modules.
list_ports () {
  local type="${1}"

  if is_not_given "${type}"; then
    log 'Missing the module type.'
    return 2
  elif is_not_module_type "${type}"; then
    log 'Invalid module type.'
    return 2
  fi

  local query='[.[]|select(.active_port)]'

  local object='sinks'
  if equals "${type}" 'input'; then
    object='sources'
  fi

  local modules=''
  modules="$(pactl --format=json list "${object}" | jq -cer "${query}")" || return 1

  local len=0
  len="$(get_len "${modules}")" || return 1

  if is_true "${len} = 0"; then
    log "No ${type} modules have found."
    return 0
  fi

  local query=''
  query+='.[]'
  query+=' |= .'
  query+=' |map(('
  query+='  .ports[] + {'
  query+='   index, state, mute, properties,'
  query+='   volume: (.volume|keys[0] as $k|.[$k].db|gsub("\\s+";""))'
  query+='  }'
  query+=' ))'
  query+=' |.[]|"'
  query+='Name:    \(.name)\n'
  query+='Card:    \(.properties|if ."device.nick" then ."device.nick" else ."device.alias" end)\n'
  query+='Volume:  \(.volume) \(if .mute then "mute" else "" end)\n'
  query+='State:   \(.state|ascii_downcase)'
  query+='"'

  query="[${query}]|join(\"\n\n\")"

  echo "${modules}" | jq -cer "${query}" || return 1
}

# Shows the list of active playbacks matching the
# given application name.
# Arguments:
#  name: the application name
# Outputs:
#  A list of playback streams.
list_playbacks () {
  local name="${1}"

  local query=''
  query="[.[]|select(.properties.\"application.name\"|test(\"${name}\"; \"i\"))]"

  local sink_inputs=''
  sink_inputs="$(pactl --format=json list sink-inputs | jq -cer "${query}")" || return 1

  local len=0
  len="$(get_len "${sink_inputs}")" || return 1

  if is_true "${len} = 0"; then
    log 'No playbacks have found.'
    return 0
  fi

  query+='|.[]|"'
  query+='Name:     \(.properties."application.name")\n'
  query+='Media:    \(.properties."media.name")\n'
  query+='\(.properties."application.process.id"|if . then "Process:  \(.)\n" else "" end)'
  query+='Volume:   \(.volume|keys[0] as $k|.[$k].db|gsub("\\s+";""))'
  query+=' \(if .mute then "mute" else "" end)'
  query+='"'

  query="[${query}]|join(\"\n\n\")"

  echo "${sink_inputs}" | jq -cer "${query}" || return 1
}

# Sets the profile of the audio card identified
# by the given name.
# Arguments:
#  card_name:   the name of an audio card
#  profile_name: a profile name of the card
set_profile () {
  local card_name="${1}"
  local profile_name="${2}"

  if is_not_given "${card_name}"; then
    on_script_mode &&
      log 'Missing the audio card name.' && return 2

    pick_card 'Select audio card name:' || return $?
    is_empty "${REPLY}" && log 'Audio card name is required.' && return 2
    card_name="${REPLY}"
  fi

  local card=''
  card="$(find_card "${card_name}")"

  if has_failed; then
    log "Audio card ${card_name} not found."
    return 2
  fi

  if is_not_given "${profile_name}"; then
    on_script_mode &&
      log 'Missing the profile name.' && return 2

    pick_profile 'Select profile name:' "${card}" || return $?
    is_empty "${REPLY}" && log 'Profile name is required.' && return 2
    profile_name="${REPLY}"
  fi

  local exists=''
  exists="$(echo "${card}" | jq -cer ".profiles|has(\"${profile_name}\")")"

  if is_false "${exists}"; then
    log 'Invalid or unknown profile name.'
    return 2
  fi

  pactl set-card-profile "${card_name}" "${profile_name}"

  if has_failed; then
    log 'Failed to set profile.'
    return 2
  fi
  
  log "Profile set to ${profile_name}."
}

# Sets the active output or input audio module.
# Arguments:
#  type: output or input
#  name: the name of the output or input module
set_default () {
  local type="${1}"
  local name="${2}"

  if is_not_given "${type}"; then
    log 'Missing the module type.'
    return 2
  elif is_not_module_type "${type}"; then
    log 'Invalid module type.'
    return 2
  fi

  if is_not_given "${name}"; then
    on_script_mode &&
      log "Missing ${type} module name." && return 2

    pick_module "Select ${type} module name:" "${type}" || return $?
    is_empty "${REPLY}" && log "${type^} module name is required." && return 2
    name="${REPLY}"
  fi

  local query=".[]|select(.name == \"${name}\")"

  local object='sink'
  if equals "${type}" 'input'; then
    object='source'
  fi

  local match=''
  match="$(pactl --format=json list "${object}s" | jq -cer "${query}")"

  if is_empty "${match}"; then
    log "${type^} module ${name} not found."
    return 2
  fi

  pactl set-default-${object} "${name}"

  if has_failed; then
    log "Failed to set active ${type}."
    return 2
  fi

  log "Active ${type} set to module ${name}."
}

# Sets the volume of the active output or input module
# to the given ivolume value. If the given value is up
# or down the volume increases or decreases by 5%.
# Arguments:
#  type:   output or input
#  volume: up, down, mute, unmute or any value in [0,150]
turn_default () {
  local type="${1}"
  local volume="${2}"

  if is_not_given "${type}"; then
    log 'Missing the module type.'
    return 2
  elif is_not_module_type "${type}"; then
    log 'Invalid module type.'
    return 2
  fi

  if is_not_given "${volume}"; then
    log 'Missing the volume value.'
    return 2
  elif is_not_valid_volume "${volume}"; then
    log 'Invalid volume value.'
    return 2
  elif is_integer "${volume}" '[0,150]'; then
    log 'Volume value is out of range.'
    return 2
  fi

  local object='sink'
  if equals "${type}" 'input'; then
    object='source'
  fi
  
  if equals "${volume}" 'mute'; then
    pactl set-${object}-mute "@DEFAULT_${object^^}@" 1

    if has_failed; then
      log "Failed to set active ${type} to mute."
      return 2
    fi

    log "Active ${type} volume set to mute."
    return 0
  elif equals "${volume}" 'unmute'; then
    pactl set-${object}-mute "@DEFAULT_${object^^}@" 0

    if has_failed; then
      log "Failed to set active ${type} to unmute."
      return 2
    fi

    log "Active ${type} volume set to unmute."
    return 0
  fi

  local action='set to'

  if equals "${volume}" 'up'; then
    volume='+1'
    action='pumped up by'
  elif equals "${volume}" 'down'; then
    volume='-1'
    action='lowered by'
  fi

  pactl set-${object}-mute "@DEFAULT_${object^^}@" 0
  pactl set-${object}-volume  "@DEFAULT_${object^^}@" "${volume}%"

  if has_failed; then
    log "Failed to set volume of active ${type}."
    return 2
  fi

  log "Active ${type} volume ${action} ${volume}%."
}

# Sets all output or input audio modules
# to mute or unmute mode.
# Arguments:
#  type: output or input
#  mode: 1 to mute or 0 to unmute
set_mute () {
  local type="${1}"
  local mode="${2}"

  if is_not_given "${type}"; then
    log 'Missing module type.'
    return 2
  elif is_not_module_type "${type}"; then
    log 'Invalid module type.'
    return 2
  fi

  if is_not_given "${mode}"; then
    log 'Missing the mute mode.'
    return 2
  elif is_not_mute_mode "${mode}"; then
    log 'Invalid mute mode.'
    return 2
  fi

  local object='sink'
  if equals "${type}" 'input'; then
    object='source'
  fi

  # Build pactl commands for each audio module
  local query=''
  query+="\"pactl set-${object}-mute \(.name) ${mode}\""
  query="[.[]|${query}]|join(\"\n\")"

  local pactl_cmds=''
  pactl_cmds="$(pactl --format=json list "${object}s" | jq -cer "${query}")" || return 1

  if is_empty "${pactl_cmds}"; then
    log "No ${type} modules have found."
    return 2
  fi

  # Execute each pactl command
  local failed='false'
  local pactl_cmd=''

  while read -r pactl_cmd; do
    ${pactl_cmd}

    if has_failed; then
      failed='true'
    fi
  done <<< "${pactl_cmds}"

  local status='unmute'
  if is_true "${mode} = 1"; then
    status='mute'
  fi

  if is_true "${failed}"; then
    log "Some ${type} modules failed to ${status}."
    return 2
  fi
  
  log "All ${type} modules set to ${status}."
}

