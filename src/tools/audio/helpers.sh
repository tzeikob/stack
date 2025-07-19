#!/bin/bash

source src/commons/input.sh
source src/commons/logger.sh
source src/commons/math.sh
source src/commons/validators.sh

# Returns the list of all audio cards.
# Outputs:
#  A json array of audio cards.
find_cards () {
  pactl --format=json list cards || return 1
}

# Returns the audio card identified by the given name.
# Arguments:
#  name: the name of audio card
# Outputs:
#  A json object of an audio card.
find_card () {
  local name="${1}"

  local query=".[] | select(.name == \"${name}\")"

  find_cards | jq -cer "${query}" || return 1
}

# Shows a menu asking the user to select an audio card.
# Arguments:
#  prompt: a prompt text line
# Outputs:
#  A menu of audio card names.
pick_card () {
  local prompt="${1}"

  local option='{key: $name, value: (.properties | ."device.nick"//."device.alias" | dft($name))}'

  local query="[.[] | .name as \$name | ${option}]"

  local cards=''
  cards="$(find_cards | jq -cer "${query}")" || return 1

  local len=0
  len=$(echo "${cards}" | jq -cer 'length') || return 1

  if is_true "${len} = 0"; then
    log 'No audio cards have found.'
    return 2
  fi
  
  pick_one "${prompt}" "${cards}" vertical || return $?
}

# Shows a menu asking the user to select a profile of the
# given audio card.
# Arguments:
#  prompt: a prompt text line
#  card:   a json object of an audio card
# Outputs:
#  A menu of audio card profile names.
pick_profile () {
  local prompt="${1}"
  local card="${2}"

  local option='{key: .key, value: .key}'

  local query="[.profiles | to_entries[] | ${option}]"

  local profiles=''
  profiles="$(echo "${card}" | jq -cer "${query}")" || return 1

  local len=0
  len="$(echo "${profiles}" | jq -cer 'length')" || return 1

  if is_true "${len} = 0"; then
    log 'No audio profiles found.'
    return 2
  fi
  
  pick_one "${prompt}" "${profiles}" vertical || return $?
}

# Shows a menu asking the user to select an audio module
# with the given type.
# Arguments:
#  prompt: a prompt text line
#  type:   output or input
# Outputs:
#  A menu of audio output or input module names.
pick_module () {
  local prompt="${1}"
  local type="${2}"

  local option='{key: .parent.name, value: "\(.name) [\(.parent.properties | ."device.nick"//."device.alias" | dft("..."))]"}'

  local query="[.[] | select(.name | contains(\"${type}\"))] | .[]"
  query+="|= . | map((.ports[] + {parent: {name, properties}})) | .[] | ${option}"
  query="[${query}]"
  
  local object='sinks'
  if equals "${type}" 'input'; then
    object='sources'
  fi

  local modules=''
  modules="$(pactl --format=json list "${object}" | jq -cer "${query}")" || return 1

  local len=0
  len="$(echo "${modules}" | jq -cer 'length')" || return 1

  if is_true "${len} = 0"; then
    log "No ${type} modules have found."
    return 2
  fi
  
  pick_one "${prompt}" "${modules}" vertical || return $?
}

# Checks if the given type is a valid io module type.
# Arguments:
#  type: a module type
# Returns:
#  0 if it is a valid io module type otherwise 1.
is_module_type () {
  local type"${1}"
  
  match "${type}" '^(output|input)$'
}

# An inverse version of is_module_type.
is_not_module_type () {
  ! is_module_type "${1}"
}

# Checks if the given value is a valid volume value.
# Arguments:
#  volume: a volume value
# Returns:
#  0 if volume is valid otherwise 1.
is_valid_volume () {
  local volume="${1}"
  
  match "${volume}" '^(up|down|mute|unmute|[0-9]+)$'
}

# An inverse version of is_valid_volume.
is_not_valid_volume () {
  ! is_valid_volume "${1}"
}

# Checks if the given mode is a valid pactl mute mode.
# Arguments:
#  mode: an integer value
# Returns:
#  0 if mode is valid otherwise 1.
is_mute_mode () {
  local mode="${1}"

  match "${mode}" '^(1|0)$'
}

# An inverse version of is_mute_mode.
is_not_mute_mode () {
  ! is_mute_mode "${1}"
}
