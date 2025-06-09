#!/bin/bash

source src/commons/process.sh
source src/commons/input.sh
source src/commons/error.sh
source src/commons/logger.sh
source src/commons/math.sh
source src/commons/validators.sh
source src/tools/desktop/helpers.sh
source src/tools/displays/helpers.sh

# Shows the current status of the desktop environment.
# Outputs:
#  A verbose list of text data.
show_status () {
  local query=''
  query+='\(.os         | lbln("System"))'
  query+='\(.kernel     | lbln("Kernel"))'
  query+='\(.server     | lbln("Graphics"))'
  query+='\n'
  query+='\(.compositor | lbln("Compositor"))'
  query+='\(.wm         | lbln("Windows"))'
  query+='\(.bars       | lbln("Bars"))'

  resolve_status | jq -cer --arg SPC 13 "\"${query}\"" || return 1
}

# Shows the list of all the wallpapers found under
# the wallpapers home.
# Outputs:
#  A list of wallpaper data.
list_wallpapers () {
  local wallpapers=''
  wallpapers="$(find_wallpapers)" || return 1

  local len=0
  len="$(echo "${wallpapers}" | jq -cer 'length')" || return 1

  if is_true "${len} = 0"; then
    log 'No wallpaper files found.'
    return 0
  fi

  local query=''
  query+='\(.name       | lbln("Name"))'
  query+='\(.resolution | lbln("Resolution"))'
  query+='\(.size       | lbl("Size"))'
  query="[.[] | \"${query}\"] | join(\"\n\n\")"

  echo "${wallpapers}" | jq -cer --arg SPC 13 "${query}" || return 1
}

# Sets the desktop wallpaper to the wallpaper with the given
# file name and scale mode.
# Arguments:
#  name: the filename of the wallpaper
#  mode: center, fill, max, scale or tile
set_wallpaper () {
  local name="${1}"
  local mode="${2}"

  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Missing the wallpaper file name.' && return 2

    pick_wallpaper || return $?
    is_empty "${REPLY}" && log 'Wallpaper file name required.' && return 2
    name="${REPLY}"
  fi

  if is_not_wallpaper_file "${name}"; then
    log 'Invalid or unknown wallpaper file.'
    return 2
  fi

  if is_not_given "${mode}"; then
    on_script_mode &&
      log 'Missing the alignment mode.' && return 2

    pick_alignment_mode || return $?
    is_empty "${REPLY}" && log 'Alignment mode is required.' && return 2
    mode="${REPLY}"
  fi
  
  if is_not_wallpaper_mode "${mode}"; then
    log 'Invalid alignment mode.'
    return 2
  fi

  feh --no-fehbg --bg-"${mode}" "${WALLPAPERS_HOME}/${name}"

  if has_failed; then
    log 'Failed to set wallpaper.'
    return 2
  fi

  log "Wallpaper set to ${name}."

  save_wallpaper_to_settings "${name}" "${mode}" ||
    log 'Failed to save wallpaper into settings.'
}

# Shows the data of the pointing device with the
# given name.
# Arguments:
#  name: the name of the pointing device
# Outputs:
#  A long list of pointing device data.
show_pointer () {
  local name="${1}"

  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Missing pointer name.' && return 2

    pick_pointer || return $?
    is_empty "${REPLY}" && log 'Pointer name is required.' && return 2
    name="${REPLY}"
  fi

  local pointer=''
  pointer="$(find_pointer "${name}")"

  if has_failed; then
    log "Pointer ${name} not found."
    return 2
  fi

  local query=''
  query+='\(.id          | lbln("ID"))'
  query+='\(.name        | lbln("Name"))'
  query+='\(.node        | olbln("Node"))'
  query+='\(.accel_speed | olbln("Speed"))'
  query+='\(.velocity    | olbln("Velocity"))'
  query+='\(.accel       | olbln("Accel"))'
  query+='\(.const_decel | olbln("Decel"))'
  query+='\(.adapt_decel | olbln("Adapt"))'
  query+='\(.enabled     | lbl("Enabled"))'

  echo "${pointer}" | jq -cer --arg SPC 11 "\"${query}\"" || return 1
}

# Shows the list of pointing devices currently
# connected to the system.
# Outputs:
#  A list of pointing devices.
list_pointers () {
  local pointers=''
  pointers="$(find_pointers)" || return 1

  local len=0
  len="$(echo "${pointers}" | jq -cer 'length')" || return 1

  if is_true "${len} = 0"; then
    log 'No pointers have found.'
    return 0
  fi

  local query=''
  query+='\(.id   | lbln("ID"))'
  query+='\(.name | lbl("Name"))'
  query="[.[] | \"${query}\"] | join(\"\n\n\")"

  echo "${pointers}" | jq -cer --arg SPC 7 "${query}" || return 1
}

# Sets the acceleration speed of every pointing device
# to the given speed factor, where 0 means slow and 1
# means fast.
# Arguments:
#  factor: a speed factor between [0,1]
set_pointer_speed () {
  local factor="${1}"

  if is_not_given "${factor}"; then
    log 'Missing speed factor.'
    return 2
  elif is_not_valid_pointer_speed "${factor}"; then
    log 'Invalid speed factor.'
    return 2
  fi

  # Convert factor to acceleration speed [-1,1]
  local speed=0
  speed="$(calc "(2 * ${factor}) - 1")" || return 1

  # Convert factor to velocity [0.001,10]
  local velocity=0.001
  if is_true "${factor} > 0"; then
    velocity="$(calc "10 * ${factor}")" || return 1
  fi

  local devices=''
  devices="$(xinput --list | awk '{
    if ($0 ~ "Virtual core pointer") {
      next
    } else if ($0 ~ "Virtual core keyboard") {
      exit
    }

    match($0, ".*id=([0-9]+).*", a)
    print a[1]
  }')" || return 1

  local device='' succeed='false'

  while read -r device; do
    # Assume this is a mouse device and set its acceleration speed
    xinput --set-prop "${device}" 'libinput Accel Speed' "${speed}" 1> /dev/null &&
    succeed='true' && continue

    # Otherwise assume this is a touch device and set its velocity
    xinput --set-prop "${device}" 'Device Accel Constant Deceleration' 1 1> /dev/null &&
    xinput --set-prop "${device}" 'Device Accel Adaptive Deceleration' 1 1> /dev/null &&
    xinput --set-prop "${device}" 'Device Accel Velocity Scaling' "${velocity}" 1> /dev/null &&
    succeed='true'
  done <<< "${devices}"

  if is_false "${succeed}"; then
    log 'Failed to set pointer speed.'
    return 2
  fi

  log "Pointer speed set to ${factor}."

  save_pointer_speed_to_settings "${factor}" ||
    log 'Failed to save pointer speed factor into settings.'
}

# Shows the data of the tablet device with the
# given name.
# Arguments:
#  name: the name of a tablet device
# Outputs:
#  A long list of tablet device data.
show_tablet () {
  local name="${1}"

  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Missing the table name.' && return 2

    pick_tablet || return $?
    is_empty "${REPLY}" && log 'Tablet name is required.' && return 2
    name="${REPLY}"
  fi

  local tablet=''
  tablet="$(find_tablet "${name}")"

  if has_failed; then
    log "Tablet ${name} not found."
    return 2
  fi

  local query=''
  query+='\(.id                    | lbln("ID"))'
  query+='\(.name                  | lbln("Name"))'
  query+='\(.type                  | lbln("Type"))'
  query+='\(.Area                  | olbln("Area"))'
  query+='\(.Rotate                | olbln("Rotate"))'
  query+='\(.PressureRecalibration | olbln("Pressure"))'
  query+='\(.PressCurve            | olbln("Curve"))'
  query+='\(.RawSample             | olbln("Sample"))'
  query+='\(.Mode                  | olbln("Mode"))'
  query+='\(.Touch                 | olbln("Touch"))'
  query+='\(.Gesture               | olbln("Gesture"))'
  query+='\(.TapTime               | olbln("Tap"))'
  query+='\(.CursorProx            | olbln("Cursor"))'
  query+='\(.Threshold             | olbln("Threshold"))'
  query+='\(.vendor                | lbl("Vendor"))'

  echo "${tablet}" | jq -cer --arg SPC 12 "\"${query}\"" || return 1
}

# Shows the list of stylus-pen devices currently
# connected to the system.
# Outputs:
#  A list of stylus-pen devices.
list_tablets () {
  local tablets=''
  tablets="$(find_tablets)" || return 1

  local len=0
  len="$(echo "${tablets}" | jq -cer 'length')" || return 1

  if is_true "${len} = 0"; then
    log 'No tablets have found.'
    return 0
  fi

  local query=''
  query+='\(.id     | lbln("ID"))'
  query+='\(.name   | lbln("Name"))'
  query+='\(.type   | lbln("Type"))'
  query+='\(.vendor | lbl("Vendor"))'
  query="[.[] | \"${query}\"] | join(\"\n\n\")"

  echo "${tablets}" | jq -cer --arg SPC 9 "${query}" || return 1
}

# Scales the area of the tablet with the given name,
# keeping the current aspect ratio.
# Arguments:
#  name:  the name of a tablet device
#  scale: the scale factor [0.1,1]
scale_tablet () {
  local name="${1}"
  local scale="${2}"

  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Missing the tablet name.' && return 2

    pick_tablet || return $?
    is_empty "${REPLY}" && log 'Tablet name is required.' && return 2
    name="${REPLY}"
  fi

  local tablet=''
  tablet="$(find_tablet "${name}")"

  if has_failed; then
    log "Tablet ${name} not found."
    return 2
  elif is_not_scalable "${name}"; then
    log "Tablet ${name} is not scalable."
    return 2
  fi

  if is_not_given "${scale}"; then
    on_script_mode &&
      log 'Missing the scale factor.' && return 2

    ask 'Enter the scale factor [0.1-1]:' || return $?
    is_empty "${REPLY}" && log 'Scale factor is required.' && return 2
    scale="${REPLY}"
  fi
  
  if is_not_valid_tablet_scale "${scale}"; then
    log 'Invalid scale factor.'
    return 2
  fi

  # Calculate tablet's ratio
  local area=''
  area="$(echo "${tablet}" | jq -cer '.Area')" || return 1

  local width=0
  width="$(echo "${area}" | cut -d ' ' -f 3)"

  local height=0
  height="$(echo "${area}" | cut -d ' ' -f 4)"

  local ratio=0
  ratio="$(calc "${width} / ${height}")" || return 1

  # Inverse aspect ratio for portrait layouts
  if is_true "${ratio} > 1"; then
    ratio="$(calc "1 / ${ratio}")" || return 1
  fi

  # Reset tablet area before applying the new scaling
  xsetwacom --set "${name}" ResetArea 1> /dev/null || return 1

  tablet="$(find_tablet "${name}")" || return 1
  area="$(echo "${tablet}" | jq -cer '.Area')" || return 1
  width="$(echo "${area}" | cut -d ' ' -f 3)"

  # Apply scaling factor
  width="$(calc "floor(${width} * ${scale})")" || return 1
  height="$(calc "floor(${width} * ${ratio})")"|| return 1

  xsetwacom --set "${name}" area "0 0 ${width} ${height}" 1> /dev/null

  if has_failed; then
    log "Failed to scale tablet ${name}."
    return 2
  fi

  log "Tablet ${name} scaled by ${scale}."

  save_tablet_scale_to_settings "${name}" "${scale}" ||
    log 'Failed to save the tablet scale factor.'
}

# Maps the area of the tablet with the given name
# to a target which could be any active display device
# ot the special desktop value that resets the tablet's
# mapping and ratio.
# Arguments:
#  name:   the name of a tablet device
#  target: the name of a display or desktop
map_tablet () {
  local name="${1}"
  local target="${2}"

  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Missing the tablet name.' && return 2

    pick_tablet || return $?
    is_empty "${REPLY}" && log 'Tablet name is required.' && return 2
    name="${REPLY}"
  fi

  local tablet=''
  tablet="$(find_tablet "${name}")"

  if has_failed; then
    log "Tablet ${name} not found."
    return 2
  elif is_not_scalable "${name}"; then
    log "Tablet ${name} is not scalable."
    return 2
  fi

  if is_not_given "${target}"; then
    on_script_mode &&
      log 'Missing the mapping target.' && return 2

    pick_mapping_target || return $?
    is_empty "${REPLY}" && log 'Mapping target is required.' && return 2
    target="${REPLY}"
  fi

  # Reset mapping and area if desktop is given as target
  if equals "${target}" 'desktop'; then
    xsetwacom --set "${name}" MapToOutput desktop 1> /dev/null

    if has_failed; then
      log 'Failed to reset mapping.'
      return 2
    fi

    # Restore area keeping the current scale
    local area=''
    area="$(echo "${tablet}" | jq -cer '.Area')" || return 1

    local previous_width=0
    previous_width="$(echo "${area}" | cut -d ' ' -f 3)"

    # Reset tablets area to default size
    xsetwacom --set "${name}" ResetArea 1> /dev/null || return 1

    tablet="$(find_tablet "${name}")" || return 1
    area="$(echo "${tablet}" | jq -cer '.Area')" || return 1

    local width=0
    width="$(echo "${area}" | cut -d ' ' -f 3)"

    local height=0
    height="$(echo "${area}" | cut -d ' ' -f 4)"

    # Calculate the scaling factor
    local scale=0
    scale="$(calc "${previous_width} / ${width}")" || return 1

    width="$(calc "floor(${width} * ${scale})")" || return 1
    height="$(calc "floor(${height} * ${scale})")" || return 1

    xsetwacom --set "${name}" area "0 0 ${width} ${height}" 1> /dev/null || return 1

    log 'Tablet mapping has been reset.'
    return 0
  fi

  local output=''
  output="$(find_output "${target}")"

  if has_failed; then
    log "Display ${target} not found."
    return 2
  elif is_not_active "${output}"; then
    log "Display ${target} is not active."
    return 2
  fi

  # Re-calculate tablet's area to match display's ratio
  local display_width=0
  display_width="$(echo "${output}" | jq -cer '.resolution_width')" || return 1

  local display_height=0
  display_height="$(echo "${output}" | jq -cer '.resolution_height')" || return 1

  local ratio=0
  ratio="$(calc "${display_width} / ${display_height}")" || return 1

  # Inverse aspect ratio for portrait layouts
  if is_true "${ratio} > 1"; then
    ratio="$(calc "1 / ${ratio}")" || return 1
  fi

  local area=0
  area="$(echo "${tablet}" | jq -cer '.Area')" || return 1

  local width=0
  width="$(echo "${area}" | cut -d ' ' -f 3)"

  local height=0
  height="$(calc "floor(${width} * ${ratio})")" || return 1

  xsetwacom --set "${name}" MapToOutput "${target}" 1> /dev/null &&
  xsetwacom --set "${name}" area "0 0 ${width} ${height}" 1> /dev/null

  if has_failed; then
    log "Failed to map tablet ${name}."
    return 2
  fi

  log "Tablet ${name} mapped to ${target}."
}

# Applies the pointer settings being set in the
# settings file.
init_pointer () {
  local speed='0.35'

  if file_exists "${DESKTOP_SETTINGS}"; then
    speed="$(jq '.pointer.speed//0.35' "${DESKTOP_SETTINGS}")"
  fi

  set_pointer_speed "${speed}"
}

# Applies the settings for those tablets being stored
# in the settings file.
init_tablets () {
  if file_not_exists "${DESKTOP_SETTINGS}"; then
    log 'No tablets settings found.'
    return 2
  fi

  local tablets=''
  tablets="$(jq '.tablets//empty' "${DESKTOP_SETTINGS}")"

  if is_not_given "${tablets}"; then
    log 'No tablets settings found.'
    return 2
  fi

  local output=''
  output="$(find_outputs primary | jq -cer '.[0] | .device_name')" || return 1

  tablets="$(echo "${tablets}" | jq -cr '.[] | {name, scale}')" || return 1

  # Iterate over tablet commands and execute one by one
  local tablet=''

  while read -r tablet; do
    local name=''
    name="$(echo "${tablet}" | jq -cer '.name')" || return 1

    local scale=1
    scale="$(echo "${tablet}" | jq -cer '.scale')" || return 1

    scale_tablet "${name}" "${scale}" &&
    map_tablet "${name}" "${output}" || return $?
  done <<< "${tablets}"
}

# Sets the desktop wallpaper to the wallpaper
# being set in the settings file.
init_wallpaper () {
  if file_not_exists "${DESKTOP_SETTINGS}"; then
    log 'No wallpaper settings found.'
    return 2
  fi

  local wallpaper=''
  wallpaper="$(jq '.wallpaper//empty' "${DESKTOP_SETTINGS}")"

  if is_not_given "${wallpaper}"; then
    log 'No wallpaper settings found.'
    return 2
  fi

  local name=''
  name="$(echo "${wallpaper}" | jq -cer '.name')" || return 1

  if file_not_exists "${WALLPAPERS_HOME}/${name}"; then
    log "Wallpaper ${name} not found."
    return 2
  fi

  local mode=''
  mode="$(echo "${wallpaper}" | jq -cer '.mode//""')" || return 1

  set_wallpaper "${name}" "${mode:-"center"}"
}

# Sets the compositor backend to the given engine.
# Arguments:
#  engine: xrender or glx
set_backend () {
  local engine="${1}"

  if is_not_given "${engine}"; then
    log 'Backend engine is required.'
    return 2
  elif is_not_backend_engine "${engine}"; then
    log 'Invalid or unknown backend engine.'
    return 2
  fi

  local conf_file="${HOME}/.config/picom/picom.conf"
  sed -i "s/\(backend =\).*/\1 \"${engine}\";/" "${conf_file}"

  if has_failed; then
    log "Failed to set backend to ${engine}."
    return 2
  fi

  log "Backend set to ${engine}."
}

# Sets the vsync mode of the compositor to on or off.
# Arguments:
#  mode: on or off
set_vsync () {
  local mode="${1}"

  if is_not_given "${mode}"; then
    log 'Vsync mode is required.'
    return 2
  elif is_not_toggle "${mode}"; then
    log 'Invalid or unknown vsync mode.'
    return 2
  fi

  if equals "${mode}" 'on'; then
    mode='true'
  else
    mode='false'
  fi

  local conf_file="${HOME}/.config/picom/picom.conf"
  sed -i "s/\(vsync =\).*/\1 ${mode};/" "${conf_file}"

  if has_failed; then
    log "Failed to set vsync mode to ${mode}."
    return 2
  fi

  log "Vsync mode set to ${mode}."
}

# Adds a new empty workspace to the monitor with
# the given output name. If no monitor is given
# the workspace will be assigned to the focused
# monitor.
# Arguments:
#  monitor: the output name of an active monitor
add_workspace () {
  local monitor="${1}"

  if is_given "${monitor}"; then
    local output=''
    output="$(find_output "${monitor}")"

    if has_failed; then
      log "Monitor ${monitor} not found."
      return 2
    fi
  
    if is_not_connected "${output}"; then
      log "Monitor ${monitor} is disconnected."
      return 2
    elif is_not_active "${output}"; then
      log "Monitor ${monitor} is inactive."
      return 2
    fi
  fi

  # Give to the new workspace the maximun of the existing indices
  local index=0
  index="$(bspc query -D --names | awk '$0>x{x=$0};END{print x}')" || return 1
  index="$(calc "${index} + 1")"

  # Add new workspace to the monitor
  bspc monitor ${monitor} -a "${index}"

  if has_failed; then
    log "Failed to add workspace to the ${monitor:-"current"} monitor."
    return 2
  fi

  # Fix workspaces order and possible inconsistencies
  fix_workspaces 1> /dev/null

  if has_failed; then
    log "Failed to fix workspaces."
    return 2
  fi
  
  log "Workspace added to the ${monitor:-"current"} monitor."
}

# Removes a workspace with the given index.
# Arguments:
#  index: the index name of a workspace
remove_workspace () {
  local index="${1}"

  if is_not_given "${index}"; then
    on_script_mode &&
      log 'Missing the workspace index.' && return 2

    pick_workspace || return $?
    is_empty "${REPLY}" && log 'Workspace index is required.' && return 2
    index="${REPLY}"
  fi

  if workspace_not_exists "${index}"; then
    log 'Unknown or invalid workspace index.'
    return 2
  fi

  # Remove workspace
  bspc desktop "${index}" --remove

  if has_failed; then
    log "Failed to remove workspace ${index}."
    return 2
  fi

  # Fix workspaces order and possible inconsistencies
  fix_workspaces 1> /dev/null

  if has_failed; then
    log 'Failed to fix workspaces.'
    return 2
  fi

  log "Workspace ${index} has been removed."
}

# Repairs any possible inconsistencies among workspaces
# like orphan workspaces, misordered slots or dangling
# inactive monitors.
fix_workspaces () {
  # Remove dangling monitors and adopt orphan windows
  remove_dangling_monitors || return 1

  local monitors=''
  monitors="$(bspc query --monitors --names)" || return 1

  # Assign workspaces to monitors by order
  local monitor='' index=1

  while read -r monitor; do
    local slots=0
    slots="$(bspc query -T -m "${monitor}" | jq -cer '.desktops | length')" || return 1

    # Compute the index of the last slot
    local last=0
    last="$(calc "${index} + ${slots} - 1")"

    # Generate the index sequence of monitor's workspaces
    local indices=''
    indices="$(seq -s ' ' ${index} ${last})"
    
    bspc monitor "${monitor}" -d ${indices} || return 1

    # Move to the next workspace index
    index="$(calc "${last} + 1")"
  done <<< "${monitors}"

  # Adopt any possible orphan windows
  bspc wm --adopt-orphans || return 1

  log 'Workspaces have been fixed.'
}

# Initiates the desktop workspaces for any active
# display monitor. This operation removes any extra
# workspaces given to a monitor.
init_workspaces () {  
  # Remove dangling monitors and adopt orphan windows
  remove_dangling_monitors || return 1

  # Find the primary monitor output
  local primary=''
  primary="$(find_outputs 'primary' | jq -cer '.[0] | .device_name')"

  if has_failed; then
    log 'Unable to find primary monitor.'
    return 2
  fi
  
  local monitors=''
  monitors="$(bspc query --monitors --names)" || return 1

  if is_empty "${monitors}"; then
    log 'No active monitors have found.'
    return 2
  fi

  # Remove any possible extra workspaces per monitor
  local monitor=''

  while read -r monitor; do
    local slots=2

    # Give four workspace slots to the primary monitor
    if equals "${monitor}" "${primary}"; then
      slots=4
    fi

    # Find the current number of monitor's workspaces
    local desktops=''
    desktops="$(bspc query -T -m "${monitor}" | jq -cer '.desktops')" || return 1
  
    local current_slots=0
    current_slots="$(echo "${desktops}" | jq -cer 'length')" || return 1

    local subtract=0
    subtract="$(calc "${current_slots} - ${slots}")"

    # Remove extra desktops one by one
    if is_true "${subtract} > 0"; then
      local extras=''
      extras="$(echo "${desktops}" | jq -cer "[.[] | .name] | .[length - ${subtract}:] | .[]")" || return 1

      local extra=''

      while read -r extra; do
        bspc desktop "${extra}" -r && bspc wm --adopt-orphans
      done <<< "${extras}"
    fi
  done <<< "${monitors}"

  # Loop again monitors to fill possible empty workspace slots
  local monitor='' index=1

  while read -r monitor; do
    local slots=2

    # Give four workspace slots to the primary monitor
    if equals "${monitor}" "${primary}"; then
      slots=4
    fi

    # Compute the index of the last slot
    local last=0
    last="$(calc "${index} + ${slots} - 1")"

    # Generate the index sequence of monitor's workspaces
    local indices=''
    indices="$(seq -s ' ' ${index} ${last})"

    # Set desktop workspace and adopt possible orphan windows
    bspc monitor "${monitor}" -d ${indices} && bspc wm --adopt-orphans

    if has_failed; then
      log "Failed to assign workspaces to monitor ${monitor}."
      return 2
    fi

    # Move to the next workspace index
    index="$(calc "${last} + 1")"
  done <<< "${monitors}"

  # Initialize desktop workspaces every time a new monitor is added
  local args=()

  bspc subscribe monitor_add | while read -a args; do
    # Make sure new monitor respects padding configuration
    bspc config left_padding 0
    bspc config right_padding 0
    bspc config bottom_padding 0
    
    local query='[.[] | select(. | test("^[0-9]+$"))] | max'
    
    local max=0
    max="$(bspc query -D --names | jq --raw-input . | jq -rcs "${query}")"

    local a=0
    a="$(calc "${max} + 1")"

    local b=0
    b="$(calc "${a} + 1")"

    bspc monitor "${args[1]}" -d "${a}" "${b}"
  done &

  log 'Desktop workspaces have set.'
}

# Initiates desktop status bars.
init_bars () {  
  # Terminate already running bar instances
  polybar-msg cmd quit 1>&2

  # Launch top/bottom bars for the primary monitor
  local primary=''
  primary="$(polybar -m | awk -F':' '/primary/{print $1}')"

  MONITOR="${primary}" polybar -r primary 1>&2 & disown
  MONITOR="${primary}" polybar -r secondary 1>&2 & disown

  # Launch tertiary bars for each other monitor
  local others=''
  others="$(polybar -m | awk -F':' '!/primary/{print $1}')"

  if is_not_empty "${others}"; then
    local monitor=''

    while read -r monitor; do
      MONITOR="${monitor}" polybar -r tertiary 1>&2 & disown
    done <<< "${others}"
  fi

  sleep 1

  if is_process_down '^polybar.*'; then
    log 'Failed to launch desktop bars.'
    return 2
  fi

  log 'Desktop bars have been launched.'
}

# Initiates keyboard bindings.
init_bindings () {
  # Kill any running sxhkd processes
  kill_process '^sxhkd.*'
  
  # Launch a new instance of sxhkd process
  sxhkd 1>&2 &
  
  # Dettach it from the current shell to suppress kill outputs
  disown $! && sleep 1

  if is_process_down '^sxhkd.*'; then
    log 'Failed to launch keyboard bindings.'
    return 2
  fi

  log 'Keyboard bindings have been launched.'
}

# Starts the desktop user interface by launcing the
# compositor along with the window manager. In case
# window manager is already running it restarts it.
start () {
  # Set pointer and background color to defaults
  hsetroot -solid '#000000'
  xsetroot -cursor_name left_ptr

  # Start compositor if it is down
  if is_process_down '^picom.*'; then
    picom 1>&2 &
  fi
  
  # Restart window manager if it is already up
  if is_process_up '^bspwm.*'; then
    restart && return 0 || return $?
  fi
  
  exec bspwm 1>&2

  if has_failed; then
    log 'Failed to start desktop.'
    return 2
  fi

  log 'Desktop has been started.'
}

# Restarts the desktop user interface along with
# various complementary services like key bindings,
# wallpaper and etc.
restart () {
  # Kill any running picom processes
  kill_process '^picom.*'
  
  # Launch a new instance of picom process
  picom 1>&2 &
  
  # Dettach it from the current shell to suppress kill outputs
  disown $! && sleep 1

  # Restart window manager
  bspc wm --restart 1>&2

  if has_failed; then
    log 'Failed to restart desktop.'
    return 2
  fi

  log 'Desktop has been restarted.'
}
