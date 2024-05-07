#!/bin/bash

set -o pipefail

source /opt/stack/commons/utils.sh
source /opt/stack/tools/displays/helpers.sh

DESKTOP_SETTINGS="${CONFIG_HOME}/desktop.json"

# Returns the list of any wallpapers found under
# the wallpapers home.
# Outputs:
#  A json array of image objects.
find_wallpapers () {
  if directory_not_exists "${WALLPAPERS_HOME}"; then
    echo '[]'
    return 0
  fi

  local wallpaper=''
  wallpaper+='"\"name\": \""$1"\","'
  wallpaper+='"\"type\": \""$2"\","'
  wallpaper+='"\"resolution\": \""$3"\","'
  wallpaper+='"\"bit\": \""$5"\","'
  wallpaper+='"\"color\": \""$6"\","'
  wallpaper+='"\"size\": \""$7"\""'
  wallpaper="\"{\"${wallpaper}\"},\""

  local wallpapers=''
  wallpapers="$(identify -quiet "${WALLPAPERS_HOME}/*" 2> /dev/null |
    awk '{
      if ($1 ~ /.(jpg|jpeg|png)$/) {
        n=split($1,a,"/")
        $1=a[n]
        print '"${wallpaper}"'
      }
    }'
  )"
  
  # Remove the extra comma after the last array element
  wallpapers="${wallpapers:+${wallpapers::-1}}"

  echo "[${wallpapers}]"
}

# Shows a menu asking the user to select one wallpaper.
# Outputs:
#  A menu of wallpaper filenames.
pick_wallpaper () {
  local query='{key: .name, value: "\(.name) [\(.resolution)]"}'
  query="[.[]|${query}]"

  local wallpapers=''
  wallpapers="$(find_wallpapers | jq -cer "${query}")" || return 1

  local len=0
  len="$(count "${wallpapers}")" || return 1

  if is_true "${len} = 0"; then
    log 'No wallpaper files found.'
    return 2
  fi

  pick_one 'Select wallpaper file:' "${wallpapers}" vertical || return $?
}


# Shows a menu asking the user to select one wallpaper
# alignment mode.
# Outputs:
#  A menu of wallpaper filenames.
pick_alignment_mode () {
  local modes=''
  modes+='{"key": "center", "value": "Center"},'
  modes+='{"key": "fill", "value": "Fill"},'
  modes+='{"key": "max", "value": "Max"},'
  modes+='{"key": "scale", "value": "Scale"},'
  modes+='{"key": "tile", "value": "Tile"}'
  modes="[${modes}]"

  pick_one 'Select alignment mode:' "${modes}" vertical || return $?
}

# Returns the list of pointing devices currently
# connected to the system.
# Outputs:
#  A json array of pointing device objects.
find_pointers () {
  local pointers=''
  pointers="$(xinput --list | awk '{
    if ($0 ~ "Virtual core pointer") {
      next
    } else if ($0 ~ "Virtual core keyboard") {
      exit
    }

    match($0, ".*↳ (.*)id=([0-9]+).*", a)
    gsub(/^[ \t]+/,"",a[1])
    gsub(/[ \t]+$/,"",a[1])
    gsub(/^[ \t]+/,"",a[2])
    gsub(/[ \t]+$/,"",a[2])

    schema="\"id\": \"%s\","
    schema=schema"\"name\": \"%s\""
    schema="{"schema"},"

    printf schema, a[2], a[1]
  }')" || return 1

  # Remove the extra comma after the last element
  pointers="${pointers:+${pointers::-1}}"

  echo "[${pointers}]"
}

# Returns the pointing device with the given name.
# Arguments:
#  name: the name of the pointing device
# Outputs:
#  A json object of pointing device.
find_pointer () {
  local name="${1}"

  local id=''
  id="$(find_pointers |
    jq -cer ".[]|select(.name == \"${name}\")|.id")" || return 1

  local pointer=''
  pointer+="\"id\":\"${id}\","
  pointer+="\"name\":\"${name}\","

  pointer+="$(xinput --list-props "${id}" | awk '{
    match($0, "(.*)\\([0-9]{3}\\):(.*)", a)
    gsub(/^[ \t]+/,"",a[1])
    gsub(/[ \t]+$/,"",a[1])
    gsub(/^[ \t]+/,"",a[2])
    gsub(/[ \t]+$/,"",a[2])
    key=a[1];value=a[2]

    if (key == "Device Node") {
      key="node"
      gsub(/"/,"",value)
    } else if (key == "Device Enabled") {
      key="enabled"
    } else if (key == "libinput Accel Speed") {
      key="accel_speed"
    } else if (key == "libinput Accel Profile Enabled") {
      key="accel"
    } else if (key == "Device Accel Constant Deceleration") {
      key="const_decel"
    } else if (key == "Device Accel Adaptive Deceleration") {
      key="adapt_decel"
    } else if (key == "Device Accel Velocity Scaling") {
      key="velocity"
    } else {
      next
    }

    print "\""key"\":\""value"\","
  }')" || return 1

  # Remove the extra comma after the last element
  pointer="${pointer:+${pointer::-1}}"

  echo "{${pointer}}"
}

# Shows a menu asking the user to select one pointing device.
# Outputs:
#  A menu of pointing devices.
pick_pointer () {
  local pointers=''
  pointers="$(find_pointers)" || return 1

  local len=0
  len="$(count "${pointers}")" || return 1

  if is_true "${len} = 0"; then
    log 'No pointers found.'
    return 2
  fi

  local query='[.[]|{key: .name, value: "\(.name)"}]'
  pointers="$(echo "${pointers}" | jq -cer "${query}")" || return 1

  pick_one 'Select pointer name:' "${pointers}" vertical || return $?
}

# Returns the list of stylus-pen devices currently
# connected to the system.
# Outputs:
#  A json array of stylus-pen device objects.
find_tablets () {
  local tablets=''
  tablets="$(xsetwacom --list devices | awk '{
    match($0, "(.*)id:(.*)type:(.*)", a)
    gsub(/^[ \t]+/,"",a[1])
    gsub(/[ \t]+$/,"",a[1])
    gsub(/^[ \t]+/,"",a[2])
    gsub(/[ \t]+$/,"",a[2])
    gsub(/^[ \t]+/,"",a[3])
    gsub(/[ \t]+$/,"",a[3])

    schema="\"id\": \"%s\","
    schema=schema"\"name\": \"%s\","
    schema=schema"\"type\": \"%s\","
    schema=schema"\"vendor\": \"wacom\""
    schema="{"schema"},"

    printf schema, a[2], a[1], a[3]
  }')" || return 1

  # Remove the extra comma after the last element
  tablets="${tablets:+${tablets::-1}}"

  echo "[${tablets}]"
}

# Returns the tablet device with the given name.
# Arguments:
#  name: the name of the tablet device
# Outputs:
#  A json object of tablet device.
find_tablet () {
  local name="${1}"

  local query=".[]|select(.name == \"${name}\")"

  local tablet=''
  tablet="$(find_tablets | jq -cer "${query}")" || return 1

  local vendor=''
  vendor="$(get "${tablet}" '.vendor')" || return 1

  # Merge properties specific to wacom devices
  if equals "${vendor}" 'wacom'; then
    local props=''
    props="$(xsetwacom --get "${name}" all 2>&1 | awk '/^Option/{
      match($0, "Option \"(.*)\" \"(.*)\"", a)
      print "\""a[1]"\": \""a[2]"\","
    }')" || return 1

    # Remove the extra comma after the last key/value pair
    props="${props:+${props::-1}}"

    tablet="$(echo "${tablet}" | jq -cer --argjson p "{${props}}" '. + $p')" || return 1
  fi

  echo "${tablet}"
}

# Checks if the given name corresponds to an
# existing tablet device.
# Arguments:
#  name: the name of a tablet device
# Returns:
#  0 if it is a tablet otherwise 1.
is_tablet () {
  local name="${1}"

  local query=".[]|select(.name == \"${name}\")"

  local tablet=''
  tablet="$(find_tablets | jq -cer "${query}")" || return 1

  if is_empty "${tablet}"; then
    return 1
  fi

  return 0
}

# An inverse version of is_tablet.
is_not_tablet () {
  is_tablet "${1}" && return 1 || return 0
}

# Checks if the tablet device with the given name
# has a scalable and mappable area.
# Arguments:
#  name: the name of a tablet device
# Returns:
#  0 if it is scalable otherwise 1.
is_scalable () {
  local name="${1}"

  local area=''
  area="$(find_tablet "${name}" | jq -cer '.Area')" || return 1

  if is_empty "${area}"; then
    return 1
  fi

  return 0
}

# An inverse version of is_scalable.
is_not_scalable () {
  is_scalable "${1}" && return 1 || return 0
}

# Shows a menu asking the user to select one tablet device.
# Outputs:
#  A menu of tablet devices.
pick_tablet () {
  local tablets=''
  tablets="$(find_tablets)" || return 1

  local len=0
  len="$(count "${tablets}")" || return 1

  if is_true "${len} = 0"; then
    log 'No tablets have found.'
    return 2
  fi

  local query='[.[]|{key: .name, value: .name}]'
  tablets="$(echo "${tablets}" | jq -cer "${query}")" || return 1

  pick_one 'Select tablet name:' "${tablets}" vertical || return $?
}

# Saves the wallpaper with the given file name
# into the settings file.
# Arguments:
#  name: the file name of the wallpaper
#  mode: center, fill, max, scale or tile
save_wallpaper_to_settings () {
  local name="${1}"
  local mode="${2}"

  local settings='{}'
  local wallpaper="{\"name\": \"${name}\", \"mode\": \"${mode}\"}"

  if file_exists "${DESKTOP_SETTINGS}"; then
    settings="$(jq -e ".wallpaper = ${wallpaper} " "${DESKTOP_SETTINGS}")" || return 1
  else
    settings="$(echo "{\"wallpaper\": ${wallpaper}}" | jq -e '.')" || return 1
  fi

  mkdir -p "${CONFIG_HOME}"
  echo "${settings}" > "${DESKTOP_SETTINGS}"
}

# Saves the pointer speed factor into the settings file.
# Arguments:
#  factor: a speed factor between [0,1]
save_pointer_speed_to_settings () {
  local factor="${1}"

  local settings='{}'
  local pointer="{\"speed\": ${factor}}"

  if file_exists "${DESKTOP_SETTINGS}"; then
    settings="$(jq -e ".pointer = ${pointer} " "${DESKTOP_SETTINGS}")" || return 1
  else
    settings="$(echo "{\"pointer\": ${pointer}}" | jq -e '.')" || return 1
  fi

  mkdir -p "${CONFIG_HOME}"
  echo "${settings}" > "${DESKTOP_SETTINGS}"
}

# Saves the scale factor of the tablet with the given
# name into the settings file.
# Arguments:
#  name:  the name of a tablet device
#  scale: the scale factor [0.1,1]
save_tablet_scale_to_settings () {
  local name="${1}"
  local scale="${2}"
  
  local settings='{}'
  local tablet="{\"name\": \"${name}\", \"scale\": ${scale}}"

  if file_exists "${DESKTOP_SETTINGS}"; then
    local tablets=''
    tablets="$(jq '.tablets|if . then . else empty end' "${DESKTOP_SETTINGS}")"

    if is_given "${tablets}"; then
      local query=''
      query=".tablets[]|select(.name == \"${name}\")"

      local match=''
      match="$(jq "${query}" "${DESKTOP_SETTINGS}")"

      if is_empty "${match}"; then
        query=".tablets += [${tablet}]"
      else
        query="(${query}|.scale)|= ${scale}"
      fi

      settings="$(jq -e "${query}" "${DESKTOP_SETTINGS}")" || return 1
    else
      settings="$(jq -e ".tablets = [${tablet}] " "${DESKTOP_SETTINGS}")" || return 1
    fi
  else
    settings="$(echo "{\"tablets\": [${tablet}]}" | jq -e '.')" || return 1
  fi

  mkdir -p "${CONFIG_HOME}"
  echo "${settings}" > "${DESKTOP_SETTINGS}"
}

# Shows a menu asking user to select a mapping target which
# could be any active display output or the special desktop
# value.
# Outputs:
#  A menu of display namesi and desktop.
pick_mapping_target () {
  # Convert outputs list into an array of {key, value} options
  local key='\(.device_name)'
  local value='\(.device_name):[\(if .model_name then .model_name else "NA" end)]'

  local query="[.[]|{key: \"${key}\", value: \"${value}\"}]"

  local options=''
  options="$(find_outputs active | jq -cer "${query}")" || return 1

  # Append the special desktop option value into options
  local desktop='[{"key": "desktop", "value": "Desktop:[ALL]"}]'

  options="$(echo "${options}" | jq -cer --argjson d "${desktop}" '. + $d')" || return 1
  
  pick_one "Select mapping target:" "${options}" vertical || return $?
}

# Checks if the given file name is a valid wallpaper file.
# Arguments:
#  file_name: the name of a wallpaper file
# Returns:
#  0 if file is a wallpaper file otherwise 1.
is_wallpaper_file () {
  local file_name="${1}"

  local file_path="${WALLPAPERS_HOME}/${file_name}"

  if file_not_exists "${file_path}"; then
    return 1
  elif not_match "${file_path}" '.+\.(jpg|jpeg|png)$'; then
    return 1
  fi

  return 0
}

# An inverse version of is_wallpaper_file.
is_not_wallpaper_file () {
  is_wallpaper_file "${1}" && return 1 || return 0
}

# Checks if the given mode is a valid wallpaper mode.
# Arguments:
#  mode: a wallpaper alignment mode
# Returns:
#  0 if mode is valid otherwise 1.
is_wallpaper_mode () {
  local mode="${1}"

  if not_match "${mode}" '^(center|fill|max|scale|tile)$'; then
    return 1
  fi

  return 0
}

# An inverse version of is_wallpaper_mode.
is_not_wallpaper_mode () {
  is_wallpaper_mode "${1}" && return 1 || return 0
}

# Checks if the given factor is a valid pointer speed.
# Arguments:
#  factor: a pointer speed factor
# Returns:
#  0 if factor is valid otherwise 1.
is_valid_pointer_speed () {
  local factor="${1}"

  if not_match "${factor}" '^[0-9]+\.?[0-9]*$'; then
    return 1
  elif is_not_true "0 <= ${factor} <= 1"; then
    return 1
  fi

  return 0
}

# An inverse version of is_valid_pointer_speed.
is_not_valid_pointer_speed () {
  is_valid_pointer_speed "${1}" && return 1 || return 0
}

# Checks if the given scale factor is valid tablet scale.
# Arguments:
#  scale: a tablet scale factor
# Returns:
#  0 if factor is valid otherwise 1.
is_valid_tablet_scale () {
  local scale="${1}"

  if not_match "${scale}" '^[0-9]+\.?[0-9]*$'; then
    return 1
  elif is_not_true "0 < ${scale} <= 1"; then
    return 1
  fi

  return 0
}

# An inverse version of is_valid_tablet_scale.
is_not_valid_tablet_scale () {
  is_valid_tablet_scale "${1}" && return 1 || return 0
}

# Checks if the given engine is a valid picom
# compositor backend engine.
# Arguments:
#  engine: a compositor backend engine
# Returns:
#  0 if engine is valid otherwise 1.
is_backend_engine () {
  local engine="${1}"

  if not_match "${engine}" '^(xrender|glx)$'; then
    return 1
  fi

  return 0
}

# An inverse version of is_backend_engine.
is_not_backend_engine () {
  is_backend_engine "${1}" && return 1 || return 0
}

# Shows a menu of all desktop workspaces.
# Outputs:
#  A menu of workspace indexes.
pick_workspace () {  
  local query='[.[]|{key: ., value: .}]'
  
  local workspaces=''
  workspaces="$(bspc query -D --names | jq --slurp . | jq -cr "${query}")" || return 1

  local len=0
  len="$(count "${workspaces}")" || return 1

  if is_true "${len} = 0"; then
    log 'No workspaces found.'
    return 2
  fi

  pick_one 'Select workspace index:' "${workspaces}" horizontal || return $?
}

# Checks if the workspace with the given index exists.
# Arguments:
#  index: the index name of a workspace
# Returns:
#  0 if workspace exists otherwise 1.
workspace_exists () {
  local index="${1}"

  local query=".[]|select(. == ${index})"

  bspc query -D --names | jq --slurp . | jq -cer "${query}" &> /dev/null || return 1  
}

# An inverse version of workspace_exists.
workspace_not_exists () {
  workspace_exists "${1}" && return 1 || return 0
}

# Removes any dangling monitor left after a display
# monitor shut down via xrandr commands.
remove_dangling_monitors () {
  local query='[.[]|.device_name]|join(" ")'

  local active=''
  active="$(find_outputs active | jq -cer "${query}" )" || return 1

  local monitors=''
  monitors="$(bspc query --monitors --names)" || return 1

  # Find which monitors are inactive and remove them
  local monitor=''

  while read -r monitor; do
    if not_match "${active}" "${monitor}"; then
      # Remove dangling monitor from window manager
      bspc monitor "${monitor}" -r || return 1
      
      # Adopt possible orphan windows
      bspc wm --adopt-orphans || return 1
    fi
  done <<< "${monitors}"
}

