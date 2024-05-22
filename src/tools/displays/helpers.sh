#!/bin/bash

set -o pipefail

source /opt/stack/commons/input.sh
source /opt/stack/commons/logger.sh
source /opt/stack/commons/json.sh
source /opt/stack/commons/math.sh
source /opt/stack/commons/text.sh
source /opt/stack/commons/validators.sh

CONFIG_HOME="${HOME}/.config/stack"
DISPLAYS_SETTINGS="${CONFIG_HOME}/displays.json"
COLORS_HOME="${HOME}/.local/share/colors"

# Checks if the given status is among the valid
# xrandr output statuses.
# Arguments:
#  status: an output status
# Returns:
# 0 if status is valid otherwise 0
is_output_status () {
  local status="${1}"

  local statuses='connected|disconnected|active|inactive|primary'

  if not_match "${status}" "^(${statuses})$"; then
    return 1
  fi

  return 0
}

# An inverse version of is_output_status.
is_not_output_status () {
  is_output_status "${1}" && return 1 || return 0
}

# Returns a list of outputs having the given status.
# Arguments:
#  status: connected, disconnected, active, inactive or primary
# Outputs:
#  A json array of outputs.
find_outputs () {
  local status="${1}"

  local criteria='true'
  if equals "${status}" 'connected'; then
    criteria='.is_connected == true'
  elif equals "${status}" 'disconnected'; then
    criteria='.is_connected == false'
  elif equals "${status}" 'active'; then
    criteria='.is_connected == true and .resolution_width != null'
  elif equals "${status}" 'inactive'; then
    criteria='.is_connected == true and .resolution_width == null'
  elif equals "${status}" 'primary'; then
    criteria='.is_primary == true'
  fi

  # Copy EDID model data to the root level
  local model=''
  model+='model_name: (.value.props.EdidModel.name|if . and . != "" then . else "Unknown" end),'
  model+='product_id: (.value.props.EdidModel.product_id|if . and . != "" then . else "Unknown" end),'
  model+='serial_number: (.value.props.EdidModel.serial_number|if . and . != "" then . else "Unknown" end)'
  model="{${model}}"

  local query=''
  query+='.screens[]|select(.screen_number == 0)'
  query+=" |.devices[]|select(${criteria})"
  query="[[${query}]|to_entries[]|{index: .key} + .value + ${model}]"

  xrandr --props | jc --xrandr | jq -cer "${query}" || return 1
}

# Returns the output with the given name.
# Arguments:
#  name: any string
# Outputs:
#  A json object of output.
find_output () {
  local name="${1}"

  local query=".[]|select(.device_name == \"${name}\")"

  find_outputs | jq -cer "${query}" || return 1
}

# Returns a unique hashed signature of the list of the given
# outputs along with their connected devices if any. The signature
# is expected to be consistent assuming that xrandr works
# deterministically returning the outputs always in the exact
# same order.
# Arguments:
#  outputs: a json array of outputs
# Outputs:
#  A hashed signature value.
get_sig () {
  local outputs="${1}"

  local model=''
  model+='if .model_name and .is_connected and .resolution_width'
  model+=' then "_\(.model_name)_\(.product_id)_\(.serial_number)"'
  model+=' else ""'
  model+='end'

  local query=''
  query+="\"\(.device_name)\(${model})\""
  query="[.[]|${query}]|join(\",\")"

  local sig=''
  sig="$(echo "${outputs}" | jq -cer "${query}")" || return 1

  get_hash "${sig}" 6 || return 1
}

# Asserts if the given output is connected.
# Arguments:
#  output: a json object output
# Returns:
#  0 if is connected otherwise 1.
is_connected () {
  local output="${1}"

  local query='select(.is_connected)'

  echo "${output}" | jq -cer "${query}" &> /dev/null || return 1
}

# An inverse version of is_connected.
is_not_connected () {
  is_connected "${1}" && return 1 || return 0
}

# Asserts if the given output is active.
# Arguments:
#  output: a json object output
# Returns:
#  0 if is active otherwise 1.
is_active () {
  local output="${1}"

  local query='select(.is_connected and .resolution_width)'

  echo "${output}" | jq -cer "${query}" &> /dev/null || return 1
}

# An inverse version of is_active.
is_not_active () {
  is_active "${1}" && return 1 || return 0
}

# Asserts if the given output is primary.
# Arguments:
#  output: a json object output
# Returns:
#  0 if is primary otherwise 1.
is_primary () {
  local output="${1}"

  local query='select(.is_primary)'

  echo "${output}" | jq -cer "${query}" &> /dev/null || return 1
}

# An inverse version of is_primary.
is_not_primary () {
  is_primary "${1}" && return 1 || return 0
}

# Checks if the given value is a valid output resolution.
# Arguments:
#  resolution: an output resolution
# Returns:
#  0 if resolution is valid otherwise 1.
is_resolution () {
  local resolution="${1}"

  if not_match "${resolution}" '^[0-9]+x[0-9]+i?$'; then
    return 1
  fi

  return 0
}

# An inverse version of is_resolution.
is_not_resolution () {
  is_resolution "${1}" && return 1 || return 0
}

# Asserts if an output supports the given resolution.
# Arguments:
#  output:     a json object of output
#  resolution: an output resolution
# Returns:
#  0 if output supports the resolution otherwise 1.
has_resolution () {
  local output="${1}"
  local resolution="${2}"

  local query=''
  query+='.resolution_modes[]'
  query+=' |"\(.resolution_width)x\(.resolution_height)\(if .is_high_resolution then "i" else "" end)" as $res'
  query+=" |select(\$res == \"${resolution}\")"

  echo "${output}" | jq -cer "${query}" &> /dev/null || return 1
}

# An inverse version of has_resolution.
has_no_resolution () {
  has_resolution "${1}" "${2}" && return 1 || return 0
}

# Checks if the given resolution rate is valid.
# Arguments:
#  rate: a resolution rate
# Returns:
#  0 if rate is valid otherwise 1.
is_rate () {
  local rate="${1}"
  
  if not_match "${rate}" '^[0-9][0-9]+(.[0-9][0-9]*)?$'; then
    return 1
  fi

  return 0
}

# An inverse version of is_rate.
is_not_rate () {
  is_rate "${1}" && return 1 || return 0
}

# Asserts if an output at a resolution supports
# the given refresh rate.
# Arguments:
#  output:     a json object of output
#  resolution: an output resolution
#  rate:       a refresh rate
# Returns:
#  0 if output supports the refresh rate otherwise 1.
has_rate () {
  local output="${1}"
  local resolution="${2}"
  local rate="${3}"

  local query=''
  query+='.resolution_modes[]'
  query+=' |"\(.resolution_width)x\(.resolution_height)\(if .is_high_resolution then "i" else "" end)" as $res'
  query+=" |select(\$res == \"${resolution}\")"
  query+=" |.frequencies[]|select(.frequency == ${rate})"

  echo "${output}" | jq -cer "${query}" &> /dev/null || return 1
}

# An inverse version of has_rate.
has_no_rate () {
  has_rate "${1}" "${2}" "${3}" && return 1 || return 0
}

# Shows a menu asking the user to select one output.
# Arguments:
#  prompt: a prompt text line
#  status: connected, disconnected, active, inactive or primary
# Outputs:
#  A menu of output names.
pick_output () {
  local prompt="${1}"
  local status="${2}"

  # Convert outputs list into an array of {key, value} options
  local key='\(.device_name)'
  local value='\(.device_name):[\(if .is_connected then .model_name else "detached" end)]'

  local query="[.[]|{key: \"${key}\", value: \"${value}\"}]"

  local options=''
  options="$(find_outputs "${status}" | jq -cer "${query}")" || return 1

  local len=0
  len="$(get_property "${options}" 'length')" || return 1
  
  if is_true "${len} = 0"; then
    log "No ${status:-\b} outputs have found."
    return 2
  fi

  pick_one "${prompt}" "${options}" vertical || return $?
}

# Shows a menu asking the user to select many outputs.
# Arguments:
#  prompt:  a prompt text line
#  status:  connected, disconnected, active, inactive or primary
#  skip:    the name of output to except from selection
# Outputs:
#  A menu of output names.
pick_outputs () {
  local prompt="${1}"
  local status="${2}"
  local skip="${3}"

  local except='select(true)'

  if is_given "${skip}"; then
    except="select(.device_name != \"${skip}\")"
  fi

  # Convert outputs list into an array of {key, value} options
  local key='\(.device_name)'
  local value='\(.device_name) [\(if .is_connected then .model_name else "detached" end)]'

  local query="{key: \"${key}\", value: \"${value}\"}"
  query="[.[]|${except}|${query}]"

  local options=''
  options="$(find_outputs "${status}" | jq -cer "${query}")" || return 1

  local len=0
  len="$(get_property "${options}" 'length')" || return 1

  if is_true "${len} = 0"; then
    log "No ${status:-\b} outputs have found."
    return 2
  fi

  pick_many "${prompt}" "${options}" vertical || return $?
}

# Shows a menu of resolutions of the given output and waits
# the user to pick one option.
# Arguments:
#  output: a json object of output
# Outputs:
#  A menu of resolutions.
pick_resolution () {
  local output="${1}"

  # Convert resolutions list into an array of {key, value} options
  local query=''
  query+='.resolution_modes[]'
  query+=' |"\(.resolution_width)x\(.resolution_height)\(if .is_high_resolution then "i" else "" end)" as $res'
  query+=' |(reduce .frequencies[] as $i (""; if $i.is_preferred then . + "*" else . end)) as $pref'
  query+=' |{key: "\($res)", value: "\($res)\($pref)"}'
  query="[${query}]"

  local options=''
  options="$(echo "${output}" | jq -cer "${query}")" || return 1

  local len=0
  len="$(get_property "${options}" 'length')" || return 1

  if is_true "${len} = 0"; then
    log 'No resolutions have found.'
    return 2
  fi

  pick_one 'Select resolution:' "${options}" vertical || return $?
}

# Shows a menu of resolution rates of the given output and
# waits the user to pick one option.
# Arguments:
#  output: a json object of output
# Outputs:
#  A menu of resolution rates.
pick_rate () {
  local output="${1}"
  local resolution="${2}"

  # Convert rates list into an array of {key, value} options
  local query=''
  query+='.resolution_modes[]'
  query+=' |"\(.resolution_width)x\(.resolution_height)\(if .is_high_resolution then "i" else "" end)" as $res'
  query+=" |select(\$res == \"${resolution}\")"
  query+=' |.frequencies[]'
  query+=' |"\(.frequency)" as $freq'
  query+=' |"\(if .is_preferred then "*" else "" end)" as $pref'
  query+=' |{key: "\($freq)", value: "\($freq)\($pref)"}'
  query="[${query}]"

  local options=''
  options="$(echo "${output}" | jq -cer "${query}")" || return 1

  local len=0
  len="$(get_property "${options}" 'length')" || return 1

  if is_true "${len} = 0"; then
    log 'No refresh rates have found.'
    return 2
  fi

  pick_one 'Select refresh rate:' "${options}" vertical || return $?
}

# Shows a menu asking the user to select a reflection mode.
# Outputs:
#  A menu of reflection modes.
pick_reflection_mode () {
  local modes=''
  modes+='{"key": "normal", "value": "Normal"},'
  modes+='{"key": "x", "value": "X Axis"},'
  modes+='{"key": "y", "value": "Y Axis"},'
  modes+='{"key": "xy", "value": "XY Axis"}'
  modes="[${modes}]"

  pick_one 'Select reflection mode:' "${modes}" horizontal || return $?
}

# Checks if the given mode is a valid reflection mode.
# Arguments:
#  mode: a reflection mode
# Returns:
#  0 if reflection mode is valid otherwise 1.
is_reflection_mode () {
  local mode="${1}"
  
  if not_match "${mode}" '^(normal|x|y|xy)$'; then
    return 1
  fi
}

# An inverse version of is_reflection_mode.
is_not_reflection_mode () {
  is_reflection_mode "${1}" && return 1 || return 0 
}

# Shows a menu asking the user to select a rotation mode.
# Outputs:
#  A menu of rotation modes.
pick_rotation_mode () {
  local modes=''
  modes+='{"key": "normal", "value": "Normal"},'
  modes+='{"key": "right", "value": "Right"},'
  modes+='{"key": "left", "value": "Left"},'
  modes+='{"key": "inverted", "value": "Inverted"}'
  modes="[${modes}]"

  pick_one 'Select rotation mode:' "${modes}" horizontal || return $?
}

# Checks if the given mode is a valid rotation mode.
# Arguments:
#  mode: a rotation mode
# Returns:
#  0 if rotation mode is valid otherwise 1.
is_rotation_mode () {
  local mode="${1}"
  
  if not_match "${mode}" '^(normal|right|left|inverted)$'; then
    return 1
  fi
}

# An inverse version of is_rotation_mode.
is_not_rotation_mode () {
  is_rotation_mode "${1}" && return 1 || return 0 
}

# Returns the common resolution if any among the
# outputs with the given names.
# Arguments:
#  names: a list of comma separated output names
# Outputs:
#  A json array of resolutions.
find_common_resolutions () {
  local names=("${@}")

  local outputs=''
  outputs="$(find_outputs)" || return 1

  local len=0
  len="$(get_property "${outputs}" 'length')" || return 1

  if is_true "${len} = 0"; then
    echo '[]'
    return 0
  fi

  # Turn names array into a disjuctive regular expression
  names="$(echo "${names[@]}" | tr ' ' '|')"

  local query=''
  query+="select(.device_name | match(\"(${names})\"))"
  query+=' |.resolution_modes[]'
  query+=' |"\(.resolution_width)x\(.resolution_height)\(if .is_high_resolution then "i" else "" end)"'
  query="[.[]|${query}]|[group_by(.)|map(select(length>1))|.[]|.[0]]"

  echo "${outputs}" | jq -cer "${query}" || return 1
}

# Show a menu of asking the user to select one of the
# available layout modes.
# Arguments
#  size: the number of active outputs
# Outputs:
#  A menu of layout modes.
pick_layout_mode () {
  local size="${1}"

  local modes=''

  if is_true "${size} = 2"; then
    modes+='{"key": "row-2", "value": "Row"},'
    modes+='{"key": "col-2", "value": "Column"}'
  elif is_true "${size} = 3"; then
    modes+='{"key": "row-3", "value": "Row"},'
    modes+='{"key": "col-3", "value": "Column"},'
    modes+='{"key": "gamma-3", "value": "Gamma"},'
    modes+='{"key": "gamma-rev-3", "value": "Gamma Reverse"},'
    modes+='{"key": "lambda-3", "value": "Lambda"},'
    modes+='{"key": "lambda-rev-3", "value": "Lambda Reverse"}'
  elif is_true "${size} = 4"; then
    modes+='{"key": "grid-4", "value": "Grid"},'
    modes+='{"key": "taph-4", "value": "Taph"},'
    modes+='{"key": "taph-rev-4", "value": "Taph Reverse"},'
    modes+='{"key": "taph-right-4", "value": "Taph Right"},'
    modes+='{"key": "taph-left-4", "value": "Taph Left"}'
  else
    log "No layout mode found for ${size} outputs."
    return 2
  fi

  pick_one 'Select layout mode:' "[${modes}]" vertical || return $?
}

# Validates the given layout mode for the given active
# outputs.
# Arguments:
#  mode: row-2, col-2, row-3, col-3, gamma-3, gamma-rev-3,
#        lambda-3, lambda-rev-3, grid-4, taph-4, taph-rev-4,
#        taph-right-4, taph-left-4
#  size: the number of active outputs
# Returns:
#  0 if layout mode corresponds to active outputs otherwise 1.
is_eligible_layout_mode () {
  local mode="${1}"
  local size="${2}"

  local modes=''
  
  if is_true "${size} = 2"; then
    modes='row-2|col-2'
  elif is_true "${size} = 3"; then
    modes='row-3|col-3|gamma-3|gamma-rev-3|lambda-3|lambda-rev-3'
  elif is_true "${size} = 4"; then
    modes='grid-4|taph-4|taph-rev-4|taph-right-4|taph-left-4'
  else
    return 1
  fi
  
  if not_match "${mode}" "^(${modes})$"; then
    return 1
  fi

  return 0
}

# An inverse version of is_eligible_layout_mode.
is_not_eligible_layout_mode () {
  is_eligible_layout_mode "${1}" "${2}" && return 1 || return 0
}

# Shows the layout topology map that corresponds to the
# given layout mode.
# Arguments:
#  mode:    row-2, col-2, row-3, col-3, gamma-3, gamma-rev-3,
#           lambda-3, lambda-rev-3, grid-4, taph-4, taph-rev-4,
#           taph-right-4, taph-left-4
# Outputs:
#  The topology of the layout mode.
show_layout_map () {
  local mode="${1}"
  
  local c=$'\e[30m\e[47m'
  local r=$'\e[0m'

  echo
  case "${mode}" in
    row-2)
      echo -e "${c}       ${r}  ${c}       ${r}"
      echo -e "${c}  |1|  ${r}  ${c}  |2|  ${r}"
      echo -e "${c}       ${r}  ${c}       ${r}"
      ;;
    col-2)
      echo -e "${c}       ${r}"
      echo -e "${c}  |1|  ${r}"
      echo -e "${c}       ${r}"
      echo
      echo -e "${c}       ${r}"
      echo -e "${c}  |2|  ${r}"
      echo -e "${c}       ${r}"
      ;;
    row-3)
      echo -e "${c}       ${r}   ${c}       ${r}   ${c}       ${r}"
      echo -e "${c}  |1|  ${r}   ${c}  |2|  ${r}   ${c}  |3|  ${r}"
      echo -e "${c}       ${r}   ${c}       ${r}   ${c}       ${r}"
      ;;
    col-3)
      echo -e "${c}       ${r}"
      echo -e "${c}  |1|  ${r}"
      echo -e "${c}       ${r}"
      echo
      echo -e "${c}       ${r}"
      echo -e "${c}  |2|  ${r}"
      echo -e "${c}       ${r}"
      echo
      echo -e "${c}       ${r}"
      echo -e "${c}  |3|  ${r}"
      echo -e "${c}       ${r}"
      ;;
    gamma-3)
      echo -e "${c}       ${r}   ${c}       ${r}"
      echo -e "${c}  |1|  ${r}   ${c}  |2|  ${r}"
      echo -e "${c}       ${r}   ${c}       ${r}"
      echo
      echo -e "${c}       ${r}"
      echo -e "${c}  |3|  ${r}"
      echo -e "${c}       ${r}"
      ;;
    gamma-rev-3)
      echo -e "${c}       ${r}   ${c}       ${r}"
      echo -e "${c}  |1|  ${r}   ${c}  |2|  ${r}"
      echo -e "${c}       ${r}   ${c}       ${r}"
      echo
      echo -e "${r}       ${r}   ${c}       ${r}"
      echo -e "${r}       ${r}   ${c}  |3|  ${r}"
      echo -e "${r}       ${r}   ${c}       ${r}"
      ;;
    lambda-3)
      echo -e "${c}       ${r}"
      echo -e "${c}  |1|  ${r}"
      echo -e "${c}       ${r}"
      echo
      echo -e "${c}       ${r}   ${c}       ${r}"
      echo -e "${c}  |2|  ${r}   ${c}  |3|  ${r}"
      echo -e "${c}       ${r}   ${c}       ${r}"
      ;;
    lambda-rev-3)
      echo -e "${r}       ${r}   ${c}       ${r}"
      echo -e "${r}       ${r}   ${c}  |1|  ${r}"
      echo -e "${r}       ${r}   ${c}       ${r}"
      echo
      echo -e "${c}       ${r}   ${c}       ${r}"
      echo -e "${c}  |2|  ${r}   ${c}  |3|  ${r}"
      echo -e "${c}       ${r}   ${c}       ${r}"
      ;;
    grid-4)
      echo -e "${c}       ${r}   ${c}       ${r}"
      echo -e "${c}  |1|  ${r}   ${c}  |2|  ${r}"
      echo -e "${c}       ${r}   ${c}       ${r}"
      echo
      echo -e "${c}       ${r}   ${c}       ${r}"
      echo -e "${c}  |3|  ${r}   ${c}  |4|  ${r}"
      echo -e "${c}       ${r}   ${c}       ${r}"
      ;;
    taph-4)
      echo -e "${c}       ${r}   ${c}       ${r}   ${c}       ${r}"
      echo -e "${c}  |1|  ${r}   ${c}  |2|  ${r}   ${c}  |3|  ${r}"
      echo -e "${c}       ${r}   ${c}       ${r}   ${c}       ${r}"
      echo
      echo -e "${r}       ${r}   ${c}       ${r}"
      echo -e "${r}       ${r}   ${c}  |4|  ${r}"
      echo -e "${r}       ${r}   ${c}       ${r}"
      ;;
    taph-rev-4)
      echo -e "${r}       ${r}   ${c}       ${r}"
      echo -e "${r}       ${r}   ${c}  |1|  ${r}"
      echo -e "${r}       ${r}   ${c}       ${r}"
      echo
      echo -e "${c}       ${r}   ${c}       ${r}   ${c}       ${r}"
      echo -e "${c}  |2|  ${r}   ${c}  |3|  ${r}   ${c}  |4|  ${r}"
      echo -e "${c}       ${r}   ${c}       ${r}   ${c}       ${r}"
      ;;
    taph-right-4)
      echo -e "${c}       ${r}"
      echo -e "${c}  |1|  ${r}"
      echo -e "${c}       ${r}"
      echo
      echo -e "${c}       ${r}   ${c}       ${r}"
      echo -e "${c}  |2|  ${r}   ${c}  |3|  ${r}"
      echo -e "${c}       ${r}   ${c}       ${r}"
      echo
      echo -e "${c}       ${r}"
      echo -e "${c}  |4|  ${r}"
      echo -e "${c}       ${r}"
      ;;
    taph-left-4)
      echo -e "${r}       ${r}   ${c}       ${r}"
      echo -e "${r}       ${r}   ${c}  |1|  ${r}"
      echo -e "${r}       ${r}   ${c}       ${r}"
      echo
      echo -e "${c}       ${r}   ${c}       ${r}"
      echo -e "${c}  |2|  ${r}   ${c}  |3|  ${r}"
      echo -e "${c}       ${r}   ${c}       ${r}"
      echo
      echo -e "${r}       ${r}   ${c}       ${r}"
      echo -e "${r}       ${r}   ${c}  |4|  ${r}"
      echo -e "${r}       ${r}   ${c}       ${r}"
      ;;
    *)
      log 'Invalid or unknown layout mode.'
      return 2;;
  esac
  echo
}

# Returns the corresponding xrandr command as a jq
# template query for the given layout mode.
# Arguments:
#  mode:    row-2, col-2, row-3, col-3, gamma-3, gamma-rev-3,
#           lambda-3, lambda-rev-3, grid-4, taph-4, taph-rev-4,
#           taph-right-4, taph-left-4
# Outputs:
#  An xrandr jq template query.
layout_to_xrandr_template () {
  local mode="${1}"

  local query=''

  case "${mode}" in
    row-2)
      query='--output \(.[1]) --right-of \(.[0])'
      ;;
    col-2)
      query='--output \(.[1]) --below \(.[0])'
      ;;
    row-3)
      query='--output \(.[1]) --right-of \(.[0]) '
      query+='--output \(.[2]) --right-of \(.[1])'
      ;;
    col-3)
      query='--output \(.[1]) --below \(.[0]) '
      query+='--output \(.[2]) --below \(.[1])'
      ;;
    gamma-3)
      query='--output \(.[1]) --right-of \(.[0]) '
      query+='--output \(.[2]) --below \(.[0])'
      ;;
    gamma-rev-3)
      query='--output \(.[1]) --right-of \(.[0]) '
      query+='--output \(.[2]) --below \(.[1])'
      ;;
    lambda-3)
      query='--output \(.[1]) --below \(.[0]) '
      query+='--output \(.[2]) --right-of \(.[1])'
      ;;
    lambda-rev-3)
      query='--output \(.[2]) --right-of \(.[1]) '
      query+='--output \(.[0]) --above \(.[2])'
      ;;
    grid-4)
      query='--output \(.[1]) --right-of \(.[0]) '
      query+='--output \(.[2]) --below \(.[0]) '
      query+='--output \(.[3]) --right-of \(.[2])'
      ;;
    taph-4)
      query='--output \(.[1]) --right-of \(.[0]) '
      query+='--output \(.[2]) --right-of \(.[1]) '
      query+='--output \(.[3]) --below \(.[1])'
      ;;
    taph-rev-4)
      query='--output \(.[2]) --below \(.[0]) '
      query+='--output \(.[1]) --left-of \(.[2]) '
      query+='--output \(.[3]) --right-of \(.[2])'
      ;;
    taph-right-4)
      query='--output \(.[1]) --below \(.[0]) '
      query+='--output \(.[2]) --right-of \(.[1]) '
      query+='--output \(.[3]) --below \(.[1])'
      ;;
    taph-left-4)
      query='--output \(.[0]) --above \(.[2]) '
      query+='--output \(.[1]) --left-of \(.[2]) '
      query+='--output \(.[3]) --below \(.[2])'
      ;;
    *)
      log 'Invalid or unknown layout mode.'
      return 2;;
  esac

  echo "${query}"
}

# Saves the layout with the given signature and map
# into the settings file.
# Arguments:
#  map: the map of outputs
#  sig: the unique signature of the mapping
save_layout_to_settings () {
  local map="${1}"
  local sig="${2}"

  local layout="{\"sig\": \"${sig}\", \"map\": ${map}}"

  local settings='{}'

  if file_exists "${DISPLAYS_SETTINGS}"; then
    local layouts=''
    layouts="$(jq 'if .layouts then .layouts else empty end' "${DISPLAYS_SETTINGS}")"

    if is_not_empty "${layouts}"; then
      local query=''
      query=".layouts[]|select(.sig == \"${sig}\")"

      local match=''
      match="$(jq "${query}" "${DISPLAYS_SETTINGS}")"

      if is_not_empty "${match}"; then
        query="(${query}|.map)|= ${map}"
      else
        query=".layouts += [${layout}]"
      fi

      settings="$(jq -e "${query}" "${DISPLAYS_SETTINGS}")" || return 1
    else
      settings="$(jq -e ".layouts = [${layout}] " "${DISPLAYS_SETTINGS}")" || return 1
    fi
  else
    settings="$(echo "{\"layouts\": [${layout}]}" | jq -e '.')" || return 1
  fi

  mkdir -p "${CONFIG_HOME}"
  echo "${settings}" > "${DISPLAYS_SETTINGS}"
}

# Show a menu asking the user to select a saved layout.
# Outputs:
#  A menu of layouts.
pick_layout () {
  local devices=''
  devices+='\(if .value.model_name then "\(.key):\(.value.model_name)" else empty end)'
  devices="[.value.map|to_entries[]|\"${devices}\"]|join(\", \")"

  local query=''
  query+="{key: .key, value: \"\(.key):[\(${devices})]\"}"
  query="if .layouts|length > 0 then [.layouts|to_entries[]|${query}] else [] end"

  local layouts=''
  layouts="$(jq -cer "${query}" "${DISPLAYS_SETTINGS}")" || return 1
  
  local len=0
  len="$(get_property "${layouts}" 'length')" || return 1

  if is_true "${len} = 0"; then
    log 'No layouts have found.'
    return 2
  fi

  pick_one 'Select layout:' "${layouts}" vertical || return $?
}

# Show a menu asking the user to select a color profile
# from those saved under the local user directory.
# Outputs:
#  A menu of profile files.
pick_color_profile () {
  # List all color calibration files under $COLORS_HOME
  local query='{key: .filename, value: .filename}'
  query="[.[]|select(.filename|test(\".ic(c|m)$\"))|${query}]"

  local profiles=''
  profiles="$(ls "${COLORS_HOME}" 2> /dev/null | jc --ls | jq -cr "${query}")"
  
  local len=0
  len="$(get_property "${profiles}" 'length')" || return 1

  if is_true "${len} = 0"; then
    log 'No color profiles have found.'
    return 2
  fi

  pick_one 'Select color profile:' "${profiles}" vertical || return $?
}

# Show a menu asking the user to select a stored color
# setting from the settings file.
# Outputs:
#  A menu of color settings.
pick_color_setting () {
  local query=''
  query+='{key: .key, value: "\(.key):\(.value.model_name) [\(.value.profile)]"}'
  query="if .colors|length > 0 then [.colors|to_entries[]|${query}] else [] end"

  local colors=''
  colors="$(jq -cer "${query}" "${DISPLAYS_SETTINGS}")" || return 1
  
  local len=0
  len="$(get_property "${colors}" 'length')" || return 1

  if is_true "${len} = 0"; then
    log 'No color settings have found.'
    return 2
  fi

  pick_one 'Select a color setting:' "${colors}" vertical || return $?
}

# Saves the color profile for the given output into settings.
# Arguments:
#  output:  a json object of output
#  profile: a color profile file
save_color_to_settings () {
  local output="${1}"
  local profile="${2}"

  local query=''
  query+='model_name: .model_name,'
  query+='product_id: .product_id,'
  query+='serial_number: .serial_number,'
  query+="profile: \"${profile}\""
  query="{${query}}"

  local color=''
  color="$(echo "${output}" | jq -cr "${query}")"

  local settings='{}'

  if file_exists "${DISPLAYS_SETTINGS}"; then
    local colors=''
    colors="$(jq 'if .colors then .colors else empty end' "${DISPLAYS_SETTINGS}")"

    if is_not_empty "${colors}"; then
      local query=''
      query+='.model_name == $c.model_name and '
      query+='.product_id == $c.product_id and '
      query+='.serial_number == $c.serial_number'
      query=".colors[]|select(${query})"

      local match=''
      match="$(jq --argjson c "${color}" "${query}" "${DISPLAYS_SETTINGS}")"

      if is_not_empty "${match}"; then
        query="(${query}|.profile)|=\"${profile}\""
      else
        query=".colors += [${color}]"
      fi

      settings="$(jq -e --argjson c "${color}" "${query}" "${DISPLAYS_SETTINGS}")" || return 1
    else
      settings="$(jq -e ".colors = [${color}]" "${DISPLAYS_SETTINGS}")" || return 1
    fi
  else
    settings="$(echo "{\"colors\": [${color}]}" | jq -e '.')" || return 1
  fi

  mkdir -p "${CONFIG_HOME}"
  echo "${settings}" > "${DISPLAYS_SETTINGS}"
}

# Deletes the matching color setting for the given output.
# Arguments:
#  output: a json object of output
remove_color_from_settings () {
  local output="${1}"

  if file_not_exists "${DISPLAYS_SETTINGS}"; then
    return 0
  fi

  local query=''
  query+='.model_name == $o.model_name and '
  query+='.product_id == $o.product_id and '
  query+='.serial_number == $o.serial_number'
  query="if .colors then .colors[]|select(${query}) else empty end"

  local settings=''
  settings="$(jq -e --argjson o "${output}" "del(${query})" "${DISPLAYS_SETTINGS}")" || return 1

  echo "${settings}" > "${DISPLAYS_SETTINGS}"
}

# Checks if the given file name is a valid color
# profile file type.
#  Arguments:
#   file_name: a file name
# Returns:
#  0 if file is of color profile type otherwise 1.
is_profile_file () {
  local file_name="${1}"
  
  if not_match "${file_name}" '.ic(c|m)$'; then
    return 1
  fi

  return 0
}

# An inverse version of is_profile_file.
is_not_profile_file () {
 is_profile_file "${1}" && return 1 || return 0
}

