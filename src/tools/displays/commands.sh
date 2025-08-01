#!/bin/bash

source src/commons/process.sh
source src/commons/error.sh
source src/commons/logger.sh
source src/commons/math.sh
source src/commons/validators.sh
source src/tools/displays/helpers.sh

# Shows the current status of Xorg and active displays.
# Outputs:
#  A verbose list of text data.
show_status () {
  local space=13
  
  local query=''
  query+='\(.display | lbln("Display"))'
  query+='\(.version | lbln("Version"))'
  query+='\(.vendor  | lbln("Vendor"))'
  query+='\(.release | lbln("Release"))'
  query+='\(.xorg    | lbln("Xorg"))'
  query+='\(.buffer  | lbln("Buffer"))'
  query+='\(.order   | lbln("Order"))'
  query+='\(.screen  | lbln("Screen"))'
  query+='\(.screens | lbl("Screens"))'

  find_screen_info | jq -cer --arg SPC ${space} "\"${query}\"" || return 1

  local colors='[]'

  if file_exists "${DISPLAYS_SETTINGS}"; then
    colors="$(jq -cr '.colors//[]' "${DISPLAYS_SETTINGS}")"
  fi

  local resolution='"\(.resolution_width)x\(.resolution_height)"'

  local rate=''
  rate+='[.resolution_modes[].frequencies] | flatten |'
  rate+='[.[] | select(.is_current == true)] | .[0].frequency | unit("Hz")'

  local resolution_rate=''
  resolution_rate="(${resolution} | dft(\"...\")) + (${rate} | opt | append)"

  local offset='"[\(.offset_width), \(.offset_height)]"'

  # Reduce over color settings to match any devices having a profile set
  local color=''
  color+='reduce $c[] as $i ({};'
  color+=' if $i.model_name == $m and $i.product_id == $p and $i.serial_number == $s'
  color+='  then . + {profile: $i.profile}'
  color+='  else .'
  color+=' end'
  color+=') | .profile'

  local query=''
  query+='\(.device_name           | lbln("Output"))'
  query+='\(.model_name            | lbln("Device"))'
  query+="\(${resolution_rate}     | lbln(\"Resolution\"))"
  query+="\(${offset}              | lbln(\"Offset\"))"
  query+='\(.rotation              | lbln("Rotation"))'
  query+='\(.reflection | downcase | lbln("Reflection"))'
  query+="\(${color}               | lbl(\"Color\"; \"none\"))"

  local aliases='.model_name as $m | .product_id as $p | .serial_number as $s'

  query="sort_by(.is_primary) | reverse | .[] | ${aliases} | \"\n${query}\""

  find_outputs active | jq -cer --arg SPC ${space} --argjson c "${colors}" "${query}"

  if has_failed; then
    log 'Unable to read active outputs.'
    return 2
  fi
}

# Shows the data of the output with the given name.
# Arguments:
#  name: the name of an output
# Outputs:
#  A verbose list of text data.
show_output () {
  local name="${1}"

  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Missing the output name.' && return 2

    pick_output 'Select an output name:' || return $?
    is_empty "${REPLY}" && log 'Output name is required.' && return 2
    name="${REPLY}"
  fi

  local colors='[]'

  if file_exists "${DISPLAYS_SETTINGS}"; then
    colors="$(jq -cr '.colors//[]' "${DISPLAYS_SETTINGS}")"
  fi

  local base=''
  base+='\(.device_name                        | lbln("Name"))'
  base+='\(.model_name                         | olbln("Device"))'
  base+='\(.is_connected                       | lbln("Connected"))'
  base+='\(.is_connected and .resolution_width | lbln("Active"))'
  base+='\(.is_primary                         | lbl("Primary"))'

  local resolution='"\(.resolution_width)x\(.resolution_height)"'

  local rate=''
  rate+='[.resolution_modes[].frequencies] | flatten |'
  rate+='[.[] | select(.is_current == true)] | .[0].frequency | unit("Hz")'

  local resolution_rate=''
  resolution_rate="(${resolution} | dft(\"...\")) + (${rate} | opt | append)"

  local offset=''
  offset='"[\(.offset_width), \(.offset_height)]"'

  local extra=''
  extra+="\(${resolution_rate}     | lbln(\"Resolution\"))"
  extra+="\(${offset}              | lbln(\"Offset\"))"
  extra+='\(.rotation              | lbln("Rotation"))'
  extra+='\(.reflection | downcase | lbl("Reflection"))'

  # Reduce over color settings to match any devices have a profile set
  local color=''
  color+='reduce $c[] as $i ({};'
  color+='if $i.model_name == $m and $i.product_id == $p and $i.serial_number == $s'
  color+=' then . + {profile: $i.profile}'
  color+=' else . '
  color+='end) | .profile | lbl("Color"; "none")'

  local modes=''
  modes+='\("\(.resolution_width)x\(.resolution_height)\(if .is_high_resolution then "i" else "" end)" | spaces(10))'
  modes+='[\([.frequencies[] | .frequency] | join(", "))]'
  modes="\"${modes}\""

  local query=''
  query+="${base}"
  query+="\(if .is_connected and .resolution_width then \"\n${extra}\" else \"\" end)"
  query+="\(if .is_connected then \"\n\(${color})\" else \"\" end)"
  query+="\(.resolution_modes | if length > 0 then [.[] | ${modes}] | \"\n\" + tree(\"Modes\") else \"\" end)"

  local aliases='.model_name as $m | .product_id as $p | .serial_number as $s'

  query=".[] | ${aliases} | select(.device_name == \"${name}\") | \"${query}\""

  find_outputs | jq -cer --arg SPC 13 --argjson c "${colors}" "${query}"

  if has_failed; then
    log "Output ${name} not found."
    return 2
  fi
}

# Shows the list of outputs matching the given status.
# Arguments:
#  status: connected, disconnected, active, inactive or primary
# Outputs:
#  A list of outputs.
list_outputs () {
  local status="${1}"

  if is_given "${status}" && is_not_output_status "${status}"; then
    log 'Invalid or unknown status.'
    return 2
  fi

  local query=''
  query+='\(.device_name                        | lbln("Name"))'
  query+='\(.model_name                         | olbln("Device"))'
  query+='\(.is_connected                       | lbln("Connected"))'
  query+='\(.is_connected and .resolution_width | lbln("Active"))'
  query+='\(.is_primary                         | lbln("Primary"))'
  query=".[] |  \"${query}\""

  local outputs=''
  outputs="$(find_outputs "${status}" | jq -cr --arg SPC 12 "${query}")" || return 1

  if is_empty "${outputs}"; then
    log "No ${status:-\b} outputs have found."
    return 0
  fi

  echo "${outputs}"
}

# Sets the resolution and rate of the output with the
# given name.
# Arguments:
#  name:       the name of an output
#  resolution: a width x height resolution
#  rate:       a refresh rate number
set_mode () {
  local name="${1}"
  local resolution="${2}"
  local rate="${3}"

  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Missing the output name.' && return 2

    pick_output 'Select an output name:' active || return $?
    is_empty "${REPLY}" && log 'Output name is required.' && return 2
    name="${REPLY}"
  fi

  local output=''
  output="$(find_output "${name}")"

  if has_failed; then
    log "Output ${name} not found."
    return 2
  fi
  
  if is_not_connected "${output}"; then
    log "Output ${name} is disconnected."
    return 2
  elif is_not_active "${output}"; then
    log "Output ${name} is inactive."
    return 2
  fi

  if is_not_given "${resolution}"; then
    on_script_mode &&
      log 'Missing the resolution.' && return 2

    pick_resolution "${output}" || return $?
    is_empty "${REPLY}" && log 'Resolution is required.' && return 2
    resolution="${REPLY}"
  fi
  
  if is_not_resolution "${resolution}"; then
    log 'Invalid resolution.'
    return 2
  elif has_no_resolution "${output}" "${resolution}"; then
    log "Resolution ${resolution} is not supported."
    return 2
  fi

  if is_not_given "${rate}"; then
    on_script_mode &&
      log 'Missing the refresh rate.' && return 2

    pick_rate "${output}" "${resolution}" || return $?
    is_empty "${REPLY}" && log 'Refresh rate is required.' && return 2
    rate="${REPLY}"
  fi
  
  if is_not_rate "${rate}"; then
    log 'Invalid refresh rate.'
    return 2
  elif has_no_rate "${output}" "${resolution}" "${rate}"; then
    log "Refresh rate ${rate} is not supported."
    return 2
  fi

  xrandr --output "${name}" --mode "${resolution}" --rate "${rate}"

  if has_failed; then
    log 'Failed to set output mode.'
    return 2
  fi

  log "Output ${name} mode set to ${resolution} at ${rate}Hz."
}

# Sets the output with the given name as primary.
# Arguments:
#  name: the name of an output
set_primary () {
  local name="${1}"

  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Missing the output name.' && return 2

    pick_output 'Select an output name:' active || return $?
    is_empty "${REPLY}" && log 'Output name is required.' && return 2
    name="${REPLY}"
  fi

  local output=''
  output="$(find_output "${name}")"

  if has_failed; then
    log "Output ${name} not found."
    return 2
  fi
  
  if is_not_connected "${output}"; then
    log "Output ${name} is disconnected."
    return 2
  elif is_not_active "${output}"; then
    log "Output ${name} is inactive."
    return 2
  elif is_primary "${output}"; then
    log "Output ${name} is already primary."
    return 2
  fi

  xrandr --output "${name}" --primary

  if has_failed; then
    log 'Failed to set as primary output.'
    return 2
  fi

  # Make sure desktop is reloaded
  desktop -qs restart 1> /dev/null

  if has_failed; then
    log 'Failed to reload desktop.'
  fi
  
  log "Output ${name} set as primary."
}

# Sets the output with the given name on.
# Arguments:
#  name: the name of an output
set_on () {
  local name="${1}"

  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Missing the output name.' && return 2

    pick_output 'Select an output name:' inactive || return $?
    is_empty "${REPLY}" && log 'Output name is required.' && return 2
    name="${REPLY}"
  fi

  local output=''
  output="$(find_output "${name}")"

  if has_failed; then
    log "Output ${name} not found."
    return 2
  fi
  
  if is_not_connected "${output}"; then
    log "Output ${name} is disconnected."
    return 2
  elif is_active "${output}"; then
    log "Output ${name} is already active."
    return 2
  fi

  # Find the last in order active monitor
  local query='[.[] | select(.is_connected and .resolution_width)] |'
  query+='sort_by(.offset_height, .offset_width) |'
  query+='if length > 0 then last | .device_name else "" end'
  
  local last=''
  last="$(find_outputs | jq -cr "${query}")" || return 1

  if is_not_empty "${last}"; then
    xrandr --output "${name}" --auto --right-of "${last}"
  else
    xrandr --output "${name}" --auto
  fi

  if has_failed; then
    log 'Failed to activate output.'
    return 2
  fi

  # Make sure desktop is reloaded
  desktop -qs init wallpaper 1> /dev/null &&
    desktop -qs init bars 1> /dev/null

  if has_failed; then
    log 'Failed to reload desktop.'
  fi
  
  log "Output ${name} has been activated."
}

# Sets the output with the given name off.
# Arguments:
#  name: the name of an output
set_off () {
  local name="${1}"

  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Missing the output name.' && return 2

    pick_output 'Select an output name:' active || return $?
    is_empty "${REPLY}" && log 'Output name is required.' && return 2
    name="${REPLY}"
  fi

  local output=''
  output="$(find_output "${name}")"

  if has_failed; then
    log "Output ${name} not found."
    return 2
  fi
  
  if is_not_connected "${output}"; then
    log "Output ${name} is disconnected."
    return 2
  elif is_not_active "${output}"; then
    log "Output ${name} is already inactive."
    return 2
  elif is_primary "${output}"; then
    log 'Cannot deactivate the primary output.'
    return 2
  fi

  xrandr --output "${name}" --off

  if has_failed; then
    log 'Failed to deactivate output.'
    return 2
  fi

  # Give time to xrandr to settle
  sleep 1

  # Make sure desktop workspaces are fixed
  desktop -qs fix workspaces 1> /dev/null

  if has_failed; then
    log 'Failed to fix desktop workspaces.'
  fi
  
  log "Output ${name} has been deactivated."
}

# Sets the reflection of the output with the given name.
# Arguments:
#  name: the name of an output
#  mode: normal, x, y, xy
reflect_output () {
  local name="${1}"
  local mode="${2}"
  
  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Missing the output name.' && return 2

    pick_output 'Select an output name:' active || return $?
    is_empty "${REPLY}" && log 'Output name is required.' && return 2
    name="${REPLY}"
  fi

  local output=''
  output="$(find_output "${name}")"

  if has_failed; then
    log "Output ${name} not found."
    return 2
  fi
  
  if is_not_connected "${output}"; then
    log "Output ${name} is disconnected."
    return 2
  elif is_not_active "${output}"; then
    log "Output ${name} is inactive."
    return 2
  fi

  if is_not_given "${mode}"; then
    on_script_mode &&
      log 'Missing the reflection mode.' && return 2

    pick_reflection_mode || return $?
    is_empty "${REPLY}" && log 'Reflection mode is required.' && return 2
    mode="${REPLY}"
  fi
  
  if is_not_reflection_mode "${mode}"; then
    log 'Invalid reflection mode.'
    return 2
  fi

  xrandr --output "${name}" --reflect "${mode}"
    
  if has_failed; then
    log 'Failed to reflect output.'
    return 2
  fi

  log "Reflection of output ${name} set to ${mode}."
}

# Sets the rotation of the output with the given name.
# Arguments:
#  name: the name of an output
#  mode: normal, right, left, inverted
rotate_output () {
  local name="${1}"
  local mode="${2}"

  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Missing the output name.' && return 2

    pick_output 'Select an output name:' active || return $?
    is_empty "${REPLY}" && log 'Output name is required.' && return 2
    name="${REPLY}"
  fi

  local output=''
  output="$(find_output "${name}")"

  if has_failed; then
    log "Output ${name} not found."
    return 2
  fi
  
  if is_not_connected "${output}"; then
    log "Output ${name} is disconnected."
    return 2
  elif is_not_active "${output}"; then
    log "Output ${name} is inactive."
    return 2
  fi

  if is_not_given "${mode}"; then
    on_script_mode &&
      log 'Missing the rotation mode.' && return 2

    pick_rotation_mode || return $?
    is_empty "${REPLY}" && log 'Rotation mode is required.' && return 2
    mode="${REPLY}"
  fi
  
  if is_not_rotation_mode "${mode}"; then
    log 'Invalid rotation mode.'
    return 2
  fi

  xrandr --output "${name}" --rotate "${mode}"
    
  if has_failed; then
    log 'Failed to rotate output.'
    return 2
  fi
  
  log "Rotation of output ${name} set to ${mode}."
}

# Mirrors the output with the given name to the target outputs,
# having all mirrors run at the given resolution, which should
# be a common resolution among all outputs of the mirroring.
# All target outputs will move to position equal to the position
# of the source output inheriting its rotation and reflection mode.
# Arguments:
#  name:       the name of the source output
#  resolution: a common resolution of all outputs
#  targets:    a list of space separated output names to mirror
mirror_output () {
  local name="${1}"
  local resolution="${2}"
  local targets=("${@:3}")

  local len=0
  len="$(find_outputs active | jq -cer 'length')" || return 1

  if is_true "${len} < 2"; then
    log 'No other active outputs found.'
    return 2
  fi
  
  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Missing the output name.' && return 2

    pick_output 'Select output name:' active || return $?
    is_empty "${REPLY}" && log 'Output name is required.' && return 2
    name="${REPLY}"
  fi

  local source=''
  source="$(find_output "${name}")"

  if has_failed; then
    log "Output ${name} not found."
    return 2
  fi
  
  if is_not_connected "${source}"; then
    log "Output ${name} is disconnected."
    return 2
  elif is_not_active "${source}"; then
    log "Output ${name} is inactive."
    return 2
  fi

  if is_not_given "${resolution}"; then
    on_script_mode &&
      log 'Missing resolution.' && return 2

    pick_resolution "${source}" || return $?
    is_empty "${REPLY}" && log 'Resolution is required.' && return 2
    resolution="${REPLY}"
  fi

  if is_not_resolution "${resolution}"; then
    log 'Invalid resolution.'
    return 2
  elif has_no_resolution "${source}" "${resolution}"; then
    log "Resolution ${resolution} is not supported."
    return 2
  fi

  if is_true "${#targets[@]} = 0"; then
    on_script_mode &&
      log 'Missing target output name(s).' && return 2

    pick_outputs 'Select at least one target output:' active "${name}" || return $?
    is_empty "${REPLY}" && log 'At least one target output is required.' && return 2
    local selected="${REPLY}"

    # Convert json to array
    readarray -t targets < <(echo "${selected}" | jq -cr '.[]')
  fi

  # Validate each one of the given targets
  local target_name=''

  for target_name in "${targets[@]}"; do
    if equals "${target_name}" "${name}"; then
      log 'Source output cannot be in targets.'
      return 2
    fi

    local target=''
    target="$(find_output "${target_name}")"

    if has_failed; then
      log "Output ${target_name} not found."
      return 2
    fi
    
    if is_not_connected "${target}"; then
      log "Output ${target_name} is disconnected."
      return 2
    elif is_not_active "${target}"; then
      log "Output ${target_name} is inactive."
      return 2
    fi
  done

  # Find the common resolution modes among source and targets
  local resolutions=''
  resolutions="$(find_common_resolutions "${name}" "${targets}")" || return 1

  local resolutions_len=0
  resolutions_len="$(echo "${resolutions}" | jq -cer 'length')" || return 1

  if is_true "${resolutions_len} = 0"; then
    log 'No common resolutions found among outputs.'
    return 2
  fi

  local match=''
  match="$(echo "${resolutions}" | jq -cr ".[] | select(. == \"${resolution}\")")"

  if is_empty "${match}"; then
    log "Resolution ${resolution} is not supported by all targets."
    log "Common resolutions are $(echo ${resolutions} | jq -cr 'join(", ")')."
    return 2
  fi

  # Have targets inherit the position and rotate/reflect of the source output
  local pos=''
  pos="$(echo "${source}" | jq -r '"\(.offset_width)x\(.offset_height)"')"

  local rot=''
  rot="$(echo "${source}" | jq -r '.rotation')"

  local ref=''
  ref="$(echo "${source}" | jq -r '.reflection | downcase' |
    awk '{gsub(/( |and|axis)/,"",$0); print}')"

  local query='$ARGS.positional | .[] |'
  query+="\"--output \(.) --mode ${resolution} --pos ${pos} --rotate ${rot} --reflect ${ref}\""
  query="[${query}] | join(\" \")"
  
  # Convert targets array to a xrandr command arguments
  local mirrors=''
  mirrors="$(jq -ncer "${query}" --args -- "${targets[@]}")" || return 1

  xrandr --output "${name}" --mode "${resolution}" ${mirrors}

  if has_failed; then
    log "Failed to mirror output ${name}."
    return 2
  fi

  # Give time to xrandr to settle
  sleep 1

  # Remove all targets from window manager and adopt orphan windows
  local monitor=''

  for monitor in "${targets[@]}"; do
    bspc monitor "${monitor}" -r || return 1
    bspc wm --adopt-orphans || return 1
  done

  # Make sure ws are fixed and desktop is reloaded
  desktop -qs fix workspaces 1> /dev/null &&
    desktop -qs init bars 1> /dev/null

  if has_failed; then
    log 'Failed to reload desktop.'
  fi

  # Convert targets into a string of comma separated output names
  targets="$(jq -ncer '$ARGS.positional | join(", ")' --args -- "${targets[@]}")" || return 1
  
  log "Output ${name} mirrored to ${targets}."
}

# Sets the layout of the given active outputs to the given mode.
# Arguments:
#  mode:    row-2, col-2, row-3, col-3, gamma-3, gamma-rev-3,
#           lambda-3, lambda-rev-3, grid-4, taph-4, taph-rev-4,
#           taph-right-4, taph-left-4
#  outputs: a list of comma separated output names
set_layout () {
  local mode="${1}"
  local outputs=("${@:2}")

  local len=0
  len="$(find_outputs active | jq -cer 'length')" || return 1

  if is_true "${len} < 2"; then
    log 'No multiple active outputs found.'
    return 2
  elif is_true "${len} > 4"; then
    log 'No layout mode exists for more than 4 outputs.'
    return 2
  fi

  if is_not_given "${mode}"; then
    on_script_mode &&
      log 'Missing layout mode.' && return 2

    pick_layout_mode "${len}" || return $?
    is_empty "${REPLY}" && log 'Layout mode is required.' && return 2
    mode="${REPLY}"
  fi

  if is_not_eligible_layout_mode "${mode}" "${len}"; then
    log 'Invalid layout mode for current setup.'
    return 2
  fi

  if is_true "${#outputs[@]} = 0"; then
    on_script_mode &&
      log 'Missing output name(s).' && return 2

    show_layout_map "${mode}"
    pick_outputs 'Select output names by order:' active || return $?
    is_empty "${REPLY}" && log 'Output names are required.' && return 2
    local selected="${REPLY}"

    # Convert json to array   
    readarray -t outputs < <(echo "${selected}" | jq -cr '.[]')
  fi

  if is_true "${#outputs[@]} != ${len}"; then
    log "Exactly ${len} outputs required."
    return 2
  fi

  # Validate each one of the given outputs
  local name=''
  
  for name in "${outputs[@]}"; do
    local output=''
    output="$(find_output "${name}")"

    if has_failed; then
      log "Output ${name} not found."
      return 2
    fi
    
    if is_not_connected "${output}"; then
      log "Output ${name} is disconnected."
      return 2
    elif is_not_active "${output}"; then
      log "Output ${name} is inactive."
      return 2
    fi
  done

  # Convert outputs array to json array of names
  outputs="$(jq -nce '$ARGS.positional' --args -- "${outputs[@]}")" || return 1

  # Build the xrandr command template for the given mode
  local query=''
  query="$(layout_to_xrandr_template "${mode}")" || return 1

  local layout=''
  layout="$(echo "${outputs}" | jq -cr "\"${query}\"")"

  xrandr ${layout}

  if has_failed; then
    log "Failed to set layout ${mode,,}."
    return 2
  fi

  # Give time to xrandr to settle
  sleep 1

  # Make sure desktop workspaces are fixed
  desktop -qs fix workspaces 1> /dev/null &&
    desktop -qs init wallpaper 1> /dev/null &&
    desktop -qs init bars  1> /dev/null

  if has_failed; then
    log 'Failed to fix desktop workspaces.'
  fi

  log "Layout has been set to ${mode,,}."
}

# Saves the current layout under a unique hashed signature
# which is based on the mapping between all outputs and
# their possibly connected devices.
save_layout () {
  local outputs=''
  outputs="$(find_outputs)" || return 1

  local len=0
  len="$(echo "${outputs}" | jq -cer 'length')" || return 1

  if is_true "${len} = 0"; then
    log 'No outputs have found.'
    return 2
  fi

  # Create a hash map of <output,{device, mode}> entries
  local device=''
  device+='if .model_name and .is_connected and .resolution_width'
  device+=' then {model_name: .model_name, product_id: .product_id, serial_number: .serial_number}'
  device+=' else {} '
  device+='end'

  local res=''
  res+='.resolution_modes[] |'
  res+='"\(.resolution_width)x\(.resolution_height)\(if .is_high_resolution then "i" else "" end)" as $res |'
  res+='.frequencies[] | select(.is_current) | "--mode \($res) --rate \(.frequency)"'

  local pos='--pos \(.offset_width)x\(.offset_height)'
  local rotate='--rotate \(.rotation)'
  local reflect='--reflect \(.reflection | downcase | gsub("( |and|axis)";""))'
  local primary='if .is_primary then "--primary" else "" end'

  local query=''
  query+='if .resolution_width'
  query+=" then (${device}) * {mode: \"\(${res}) ${pos} ${rotate} ${reflect} \(${primary})\"}"
  query+=" else (${device}) * {mode: \"--off\"} "
  query+='end'

  query="map({(.device_name | tostring): (${query})}) | add"

  local map=''
  map="$(echo "${outputs}" | jq -cer "${query}")"

  if has_failed; then
    log 'Unable to parse mapping.'
    return 2
  fi

  # Assign a signature to the current layout mapping
  local sig=''
  sig="$(get_sig "${outputs}")" || return 1

  save_layout_to_settings "${map}" "${sig}"

  if has_failed; then
    log 'Failed to save layout.'
    return 2
  fi
    
  log 'Layout has been saved.'
}

# Restores the layout setting with the signature matching
# the signature of the mapping between current outputs and 
# connected devices.
restore_layout () {
  if file_not_exists "${DISPLAYS_SETTINGS}"; then
    log 'No layouts have found.'
    return 2
  fi

  local layouts=''
  layouts="$(jq '.layouts//empty' "${DISPLAYS_SETTINGS}")"

  if is_empty "${layouts}"; then
    log 'No layouts have found.'
    return 2
  fi

  local outputs=''
  outputs="$(find_outputs)" || return 1

  local len=0
  len="$(echo "${outputs}" | jq -cer 'length')" || return 1

  if is_true "${len} = 0"; then
    log 'No outputs have found.'
    return 2
  fi

  # Calculate the hashed signature of the current mapping
  local sig=''
  sig="$(get_sig "${outputs}")" || return 1

  # Search for a layout matching the current mapping
  local query=".[] | select(.sig == \"${sig}\") | .map | to_entries[] | \"--output \(.key) \(.value.mode)\""
  query="[${query}] | join(\" \")"

  local layout=''
  layout="$(echo "${layouts}" | jq -cr "${query}")"

  if is_empty "${layout}"; then
    log 'No matching layout has found.'
    return 2
  fi

  xrandr ${layout}

  if has_failed; then
    log 'Failed to restore the layout.'
    return 2
  fi

  if is_empty "${NO_DESKTOP_RESTART}" || not_equals "${NO_DESKTOP_RESTART}" 'true'; then
    # Give time to xrandr to settle
    sleep 1

    # Make sure desktop workspaces and other modules are fixed
    desktop -qs fix workspaces 1> /dev/null &&
      desktop -qs restart 1> /dev/null

    if has_failed; then
      log 'Failed to reload desktop.'
    fi
  fi

  log 'Layout has been restored.'
}

# Fixes the positioning of the current layout by
# setting forcefully to off any output being
# disconnected or inactive.
fix_layout () {
  local outputs=''
  outputs="$(find_outputs)" || return 1

  local len=0
  len="$(echo "${outputs}" | jq -cer 'length')" || return 1

  if is_true "${len} = 0"; then
    log 'No outputs have found.'
    return 2
  fi

  # Set any disconnected monitors off
  local query='.[] | select(.is_connected | not) | "--output \(.device_name) --off"'
  query="[${query}] | join(\" \")"

  local disconnected=''
  disconnected="$(echo "${outputs}" | jq -cr "${query}")"

  # Set any inactive monitors off
  local query='.[] | select(.is_connected and .resolution_width == null) | "--output \(.device_name) --off"'
  query="[${query}] | join(\" \")"

  local inactive=''
  inactive="$(echo "${outputs}" | jq -cr "${query}")"

  if is_empty "${disconnected// }" && is_empty "${inactive// }"; then
    log 'No fix applied to layout.'
    return 2
  fi

  xrandr ${disconnected} ${inactive}

  if has_failed; then
    log 'Failed to fix the layout.'
    return 2
  fi

  # Set new primary monitor if primary has disconnected
  local query='.[] | select((.is_connected | not) and .is_primary) | .device_name'

  local disconnected_primary=''
  disconnected_primary="$(echo "${outputs}" | jq -cr "${query}")"

  # Set as primary the first found active monitor
  if is_not_empty "${disconnected_primary}"; then
    local query='[.[] | select(.is_connected and .resolution_width)] | .[0].device_name'

    local new_primary=''
    new_primary="$(echo "${outputs}" | jq -cr "${query}")"

    is_not_empty "${new_primary}" && set_primary "${new_primary}"
  fi

  # Give time to xrandr to settle
  sleep 1

  # Make sure desktop workspaces are fixed
  desktop -qs fix workspaces 1> /dev/null

  if has_failed; then
    log 'Failed to fix desktop workspaces.'
  fi

  log 'Layout has been fixed.'
}

# Deletes the layout setting with the given index.
# Arguments;
#  index: the index of the layout setting
delete_layout () {
  local index="${1}"

  if file_not_exists "${DISPLAYS_SETTINGS}"; then
    log 'No layouts have found.'
    return 2
  fi

  if is_not_given "${index}"; then
    on_script_mode &&
      log 'Missing the layout index.' && return 2

    pick_layout || return $?
    is_empty "${REPLY}" && log 'Layout index is required.' && return 2
    index="${REPLY}"
  fi

  if is_not_integer "${index}" '[0,]'; then
    log 'Invalid layout index.'
    return 2
  fi

  local match=''
  match="$(jq "select(.layouts[${index}])" "${DISPLAYS_SETTINGS}")"

  if is_empty "${match}"; then
    log "Cannot find layout with index ${index}."
    return 2
  fi

  local settings=''
  settings="$(jq -e "del(.layouts | .[${index}])" "${DISPLAYS_SETTINGS}")"

  if has_failed; then
    log 'Failed to delete layout.'
    return 2
  fi

  echo "${settings}" > "${DISPLAYS_SETTINGS}"
  
  log 'Layout has been deleted.'
}

# List all the stored layout settings.
# Outputs:
#  A list of layout settings.
list_layouts () {
  if file_not_exists "${DISPLAYS_SETTINGS}"; then
    log 'No layouts have found.'
    return 0
  fi

  local map=''
  map+='if .value.mode != "--off"'
  map+=' then .key as $k | .value.model_name | lbl($k; "unknown")'
  map+=' else ""'
  map+='end'

  map="[.value.map | to_entries[] | \"\(${map})\" | select(is_nullish(.) | not)] | join(\"\n\")"

  local layout=''
  layout+='\(.key                   | lbln("Index"))'
  layout+='\(.value.sig | uppercase | lbln("SIG"))'
  layout+="\(${map})"

  local query=''
  query+='if length > 0 '
  query+=" then to_entries[] | \"${layout}\""
  query+=' else "No layouts have found"'
  query+='end'

  query=".layouts//[] | [${query}] | join(\"\n\n\")"

  jq -cer --arg SPC 10 "${query}" "${DISPLAYS_SETTINGS}" || return 1
}

# Sets the color profile of the device connected to the output
# with the given name and saves it to the color settings. The
# profile should be a file path to any .icc or .icm color file.
# Arguments:
#  name:    the name of an output
#  profile: the file path to a color profile
set_color () {
  local name="${1}"
  local profile="${2}"

  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Missing output name.' && return 2

    pick_output 'Select an output name:' active || return $?
    is_empty "${REPLY}" && log 'Output name is required.' && return 2
    name="${REPLY}"
  fi
  
  local output=''
  output="$(find_output "${name}")"

  if has_failed; then
    log "Output ${name} not found."
    return 2
  fi
  
  if is_not_connected "${output}"; then
    log "Output ${name} is disconnected."
    return 2
  elif is_not_active "${output}"; then
    log "Output ${name} is inactive."
    return 2
  fi

  if is_not_given "${profile}"; then
    on_script_mode &&
      log 'Missing the profile file path.' && return 2

    ask 'Enter the path to a profile file:' || return $?
    is_empty "${REPLY}" && log 'Profile file path is required.' && return 2
    profile="${REPLY}"
  fi

  if is_not_profile_file "${profile}"; then
    log 'Invalid color profile file.'
    return 2
  elif file_not_exists "${profile}"; then
    log "Profile file ${profile} not exists."
    return 2
  fi

  local file_name=''
  file_name="$(basename ${profile})" || return 1

  mkdir -p "${COLORS_HOME}" &&
    cp -n "${profile}" "${COLORS_HOME}/${file_name}" || return 1

  local index=''
  index="$(echo "${output}" | jq -cer '.index')" || return 1

  local result=''
  result="$(xcalib -d "${DISPLAY}" -s 0 -o "${index}" "${COLORS_HOME}/${file_name}" 2>&1)"

  if has_failed || is_not_empty "${result}"; then
    log 'Failed to set output color.'
    return 2
  fi

  log "Color of output ${name} set to ${file_name}."

  save_color_to_settings "${output}" "${file_name}" ||
    log 'Failed to save output color to settings.'
}

# Resets the color profile of the device connected to the
# output with the given name and removes it from the color
# settings.
# Arguments:
#  name: the name of an output
reset_color () {
  local name="${1}"

  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Missing the output name.' && return 2

    pick_output 'Select output name:' active || return $?
    is_empty "${REPLY}" && log 'Output name is required.' && return 2
    name="${REPLY}"
  fi

  local output=''
  output="$(find_output "${name}")"

  if has_failed; then
    log "Output ${name} not found."
    return 2
  fi
  
  if is_not_connected "${output}"; then
    log "Output ${name} is disconnected."
    return 2
  elif is_not_active "${output}"; then
    log "Output ${name} is inactive."
    return 2
  fi

  local index=''
  index="$(echo "${output}" | jq -cer '.index')" || return 1

  local result=''
  result="$(xcalib -d "${DISPLAY}" -s 0 -o "${index}" -c 2>&1)"

  if has_failed || is_not_empty "${result}"; then
    log 'Failed to reset output color.'
    return 2
  fi

  log "Color of output ${name} has been reset."

  remove_color_from_settings "${output}" ||
    log 'Failed to delete output color from settings.'
}

# List all the color settings per device being stored
# in settings.
# Outputs:
#  A list of color settings.
list_colors () {
  if file_not_exists "${DISPLAYS_SETTINGS}"; then
    log 'No color settings have found.'
    return 0
  fi

  local color=''
  color+='\(.key                 | lbln("Index"))'
  color+='\(.value.model_name    | lbln("Device"))'
  color+='\(.value.product_id    | lbln("Product"))'
  color+='\(.value.serial_number | lbln("Serial"))'
  color+='\(.value.profile       | lbl("Profile"))'

  local query=''
  query+='if length > 0'
  query+=" then to_entries[] | \"${color}\""
  query+=' else "No color settings have found"'
  query+='end'

  query="[.colors//[] | ${query}] | join(\"\n\n\")"

  jq -cer --arg SPC 10 "${query}" "${DISPLAYS_SETTINGS}" || return 1
}

# Restores the color settings of any devices currently
# connected to an output.
restore_colors () {
  if file_not_exists "${DISPLAYS_SETTINGS}"; then
    log 'No color settings have found.'
    return 2
  fi

  local colors=''
  colors="$(jq -cr '.colors//[]' "${DISPLAYS_SETTINGS}")" || return 1

  local len=0
  len="$(echo "${colors}" | jq -cer 'length')" || return 1

  if is_true "${len} = 0"; then
    log 'No color settings have found.'
    return 2
  fi

  local outputs=''
  outputs="$(find_outputs active)" || return 1

  local xcalib_cmd=''
  xcalib_cmd+="\"xcalib -d ${DISPLAY} -s 0 -o \(.index) ${COLORS_HOME}/\(.profile)\""

  local query=''
  query+='. + $c | group_by([.model_name, .product_id, .serial_number]) |'
  query+="map({index: (.[0].index), profile: (.[].profile | select(.))})[] |"
  query+="${xcalib_cmd}"

  local xcalib_cmds=''
  xcalib_cmds="$(echo "${outputs}" | jq -cr --argjson c "${colors}" "${query}")" || return 1

  # Iterate over xcalib commands and execute one by one
  local xcalib_cmd='' failed=0

  while read -r xcalib_cmd; do
    local result=''
    result="$(${xcalib_cmd} 2>&1)"

    if has_failed || is_not_empty "${result}"; then
      failed="$(calc "${failed} + 1")" || return 1
    fi
  done <<< "${xcalib_cmds}"

  if is_true "${failed} > 0"; then
    log "${failed} color settings failed to be restored."
    return 2
  fi

  log 'Color settings have been restored.'
}

# Detects if the primary output is set to a disconnected
# inactive output and if so, sets the primary to the first
# connected and active output.
fix_primary () {
  local primary=''
  primary="$(find_outputs 'primary' | jq -cer '.[0]')" || return 1

  if is_active "${primary}"; then
    log 'Primary is already set.'
    return 2
  fi

  local active_outputs=''
  active_outputs="$(find_outputs 'active')" || return 1

  local len=0
  len="$(echo "${active_outputs}" | jq -cer 'length')" || return 1

  if is_true "${len} = 0"; then
    log 'No active outputs have found.'
    return 2
  fi

  local new_primary=''
  new_primary="$(echo "${active_outputs}" | jq -cer '.[0] | .device_name')" || return 1

  xrandr --output "${new_primary}" --primary

  if has_failed; then
    log "Failed to set output ${new_primary} as primary."
    return 2
  fi

  log "Primary set to output ${new_primary}."
}
