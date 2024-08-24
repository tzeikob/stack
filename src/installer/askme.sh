#!/bin/bash

set -Eeo pipefail

source src/commons/input.sh
source src/commons/error.sh
source src/commons/logger.sh
source src/commons/text.sh
source src/commons/validators.sh

SETTINGS=./settings.json

# Asks the user to select the installation disk.
select_disk () {
  local fields='name,path,type,size,rm,ro,tran,hotplug,state,'
  fields+='vendor,model,rev,serial,mountpoint,mountpoints,'
  fields+='label,uuid,fstype,fsver,fsavail,fsused,fsuse%'

  local query='[.blockdevices[]|select(.type == "disk")]'

  local disks=''
  disks="$(
    lsblk -J -o "${fields}" | jq -cer "${query}" 2> /dev/null
  )"

  if has_failed; then
    abort 'Unable to list disk block devices.'
  fi

  local trim='.|gsub("^\\s+|\\s+$";"")'
  local vendor="\(.vendor|if . then .|${trim} else empty end)"

  local value=''
  value+="[\"${vendor}\", .rev, .serial, .size]|join(\" \")"
  value="\(${value}|if . != \"\" then \" [\(.|${trim})]\" else empty end)"
  value="\(.path)${value}"

  local query=''
  query="[.[]|{key: .path, value: \"${value}\"}]"

  disks="$(
    echo "${disks}" | jq -cer "${query}"
  )"

  if has_failed; then
    abort 'Failed to parse disks data.'
  fi

  pick_one 'Select the installation disk:' "${disks}" 'vertical' || abort
  is_not_given "${REPLY}" && abort 'User input is required.'

  local disk="${REPLY}"

  log -n "CAUTION, all data in \"${disk}\" will be lost!"
  confirm 'Do you want to proceed with this disk?' || abort

  if is_not_given "${REPLY}"; then
    abort 'User input is required.'
  fi

  if is_no "${REPLY}"; then
    abort
  fi

  local settings=''
  settings="$(jq -er ".disk = \"${disk}\"" "${SETTINGS}")" &&
    echo "${settings}" > "${SETTINGS}" ||
    abort 'Failed to save disk setting.'

  log "Installation disk set to block device ${disk}."
}

# Asks the user to enable or not the swap space.
opt_in_swap_space () {
  confirm -n 'Do you want to enable swap space?' || abort
  is_not_given "${REPLY}" && abort 'User input is required.'

  if is_no "${REPLY}"; then
    local settings=''
    settings="$(jq -er '.swap_on = "no"' "${SETTINGS}")" &&
      echo "${settings}" > "${SETTINGS}" ||
      abort 'Failed to save swap_on setting.'

    log 'Swap is set to off.'
    return 0
  fi

  local settings=''
  settings="$(jq -er '.swap_on = "yes"' "${SETTINGS}")" &&
    echo "${settings}" > "${SETTINGS}" ||
    abort 'Failed to save swap_on setting.'

  log 'Swap is set to yes.'

  ask 'Enter the size of the swap space in GBs:' || abort
  is_not_given "${REPLY}" && abort 'User input is required.'

  while is_not_integer "${REPLY}" '[1,]'; do
    ask 'Please enter a valid swap space size in GBs:' || abort
    is_not_given "${REPLY}" && abort 'User input is required.'
  done

  local swap_size="${REPLY}"

  local settings=''
  settings="$(jq -er ".swap_size = ${swap_size}" "${SETTINGS}")" &&
    echo "${settings}" > "${SETTINGS}" ||
    abort 'Failed to save swap_size setting.'

  log "Swap size is set to ${swap_size}GB."

  local swap_types=''
  swap_types+='{"key": "file", "value":"File"},'
  swap_types+='{"key": "partition", "value":"Partition"}'
  swap_types="[${swap_types}]"

  pick_one 'Which type of swap to setup:' "${swap_types}" 'horizontal' || abort
  is_not_given "${REPLY}" && abort 'User input is required.'

  local swap_type="${REPLY}"
  
  local settings=''
  settings="$(jq -er ".swap_type = \"${swap_type}\"" "${SETTINGS}")" &&
    echo "${settings}" > "${SETTINGS}" ||
    abort 'Failed to save swap_type setting.'

  log "Swap type is set to ${swap_type}."
}

# Asks the user to select the mirror countries used for installation and updates.
select_mirrors () {
  local mirrors=''
  mirrors="$(
    reflector --list-countries 2> /dev/null | tail -n +3 | awk '{
      match($0, /(.*)([A-Z]{2})\s+([0-9]+)/, a)
      gsub(/[ \t]+$/, "", a[1])

      frm="{\"key\": \"%s\", \"value\": \"%s\"},"
      printf frm, a[2], a[1]" ["a[3]"]"
    }'
  )"
  
  if has_failed; then
    abort 'Unable to fetch package databases mirrors.'
  fi

  # Remove the extra comma from the last element
  mirrors="[${mirrors:+${mirrors::-1}}]"

  pick_many -n 'Select package databases mirrors:' "${mirrors}" 'vertical' || abort
  is_not_given "${REPLY}" && abort 'User input is required.'

  mirrors="${REPLY}"

  local settings=''
  settings="$(jq -er ".mirrors = ${mirrors}" "${SETTINGS}")" &&
    echo "${settings}" > "${SETTINGS}" ||
    abort 'Failed to save mirrors setting.'

  log "Package databases mirrors are set to ${mirrors}."
}

# Asks the user to select the system's timezone.
select_timezone () {
  local timezones=''
  timezones="$(
    timedatectl list-timezones 2> /dev/null | awk '{
      print "{\"key\":\""$0"\",\"value\":\""$0"\"},"
    }'
  )"
  
  if has_failed; then
    abort 'Unable to list timezones.'
  fi

  # Remove the extra comma after the last array element
  timezones="[${timezones:+${timezones::-1}}]"

  pick_one -n 'Select the system timezone:' "${timezones}" 'vertical' || abort
  is_not_given "${REPLY}" && abort 'User input is required.'

  local timezone="${REPLY}"

  local settings=''
  settings="$(jq -er ".timezone = \"${timezone}\"" "${SETTINGS}")" &&
    echo "${settings}" > "${SETTINGS}" ||
    abort 'Failed to save timezone setting.'

  log "Timezone is set to ${timezone}."
}

# Asks the user to select which locales to install.
select_locales () {
  local locales=''
  locales="$(
    cat /etc/locale.gen | tail -n +24 | grep -E '^\s*#.*' | tr -d '#' | trim | awk '{
      print "{\"key\":\""$0"\",\"value\":\""$0"\"},"
    }'
  )"
  
  if has_failed; then
    abort 'Unable to list the locales.'
  fi
  
  # Removes the last comma delimiter from the last element
  locales="[${locales:+${locales::-1}}]"

  pick_many -n 'Select system locales by order:' "${locales}" 'vertical' || abort
  is_not_given "${REPLY}" && abort 'User input is required.'

  locales="${REPLY}"

  local settings=''
  settings="$(jq -er ".locales = ${locales}" "${SETTINGS}")" &&
    echo "${settings}" > "${SETTINGS}" ||
    abort 'Failed to save locales setting.'

  log "Locales are set to ${locales}."
}

# Asks the user to select the keyboard model.
select_keyboard_model () {
  local models=''
  models="$(
    localectl --no-pager list-x11-keymap-models 2> /dev/null | awk '{
      print "{\"key\":\""$1"\",\"value\":\""$1"\"},"
    }'
  )"
  
  if has_failed; then
    abort 'Unable to list keyboard models.'
  fi

  # Remove the extra comma delimiter from the last element
  models="[${models:+${models::-1}}]"

  pick_one -n 'Select a keyboard model:' "${models}" 'vertical' || abort
  is_not_given "${REPLY}" && abort 'User input is required.'

  local keyboard_model="${REPLY}"

  local settings=''
  settings="$(jq -er ".keyboard_model = \"${keyboard_model}\"" "${SETTINGS}")" &&
    echo "${settings}" > "${SETTINGS}" ||
    abort 'Failed to save keyboard_model setting.'

  log "Keyboard model is set to ${keyboard_model}."
}

# Asks the user to select the keyboard map.
select_keyboard_map () {
  local maps=''
  maps="$(
    localectl --no-pager list-keymaps 2> /dev/null | awk '{
      print "{\"key\":\""$0"\",\"value\":\""$0"\"},"
    }'
  )"
  
  if has_failed; then
    abort 'Unable to list keyboard maps.'
  fi
  
  # Remove extra comma delimiter from the last element
  maps="[${maps:+${maps::-1}}]"

  pick_one -n 'Select a keyboard map:' "${maps}" 'vertical' || abort
  is_not_given "${REPLY}" && abort 'User input is required.'

  local keyboard_map="${REPLY}"

  local settings=''
  settings="$(jq -er ".keyboard_map = \"${keyboard_map}\"" "${SETTINGS}")" &&
    echo "${settings}" > "${SETTINGS}" ||
    abort 'Failed to save keyboard_map setting.'

  log "Keyboard map is set to ${keyboard_map}."
}

# Asks the user to select keyboard layout.
select_keyboard_layout () {
  local layouts=''
  layouts="$(
    localectl --no-pager list-x11-keymap-layouts 2> /dev/null | awk '{
      print "{\"key\":\""$0"\",\"value\":\""$0"\"},"
    }'
  )"
  
  if has_failed; then
    abort 'Unable to list keyboard layouts.'
  fi
  
  # Remove the extra comma delimiter from last element
  layouts="[${layouts:+${layouts::-1}}]"

  pick_one -n 'Select a keyboard layout:' "${layouts}" 'vertical' || abort
  is_not_given "${REPLY}" && abort 'User input is required.'

  local keyboard_layout="${REPLY}"

  local settings=''
  settings="$(jq -er ".keyboard_layout = \"${keyboard_layout}\"" "${SETTINGS}")" &&
    echo "${settings}" > "${SETTINGS}" ||
    abort 'Failed to save keyboard_layout setting.'

  local variants='{"key": "default", "value": "default"},'
  variants+="$(
    localectl --no-pager list-x11-keymap-variants "${keyboard_layout}" 2> /dev/null  | awk '{
      print "{\"key\":\""$0"\",\"value\":\""$0"\"},"
    }'
  )"
  
  if has_failed; then
    abort 'Unable to list layout variants.'
  fi
  
  # Remove the extra comma delimiter from last element
  variants="[${variants:+${variants::-1}}]"

  pick_one -n "Select a ${keyboard_layout} layout variant:" "${variants}" vertical || abort
  is_not_given "${REPLY}" && abort 'User input is required.'

  local layout_variant="${REPLY}"

  local settings=''
  settings="$(jq -er ".layout_variant = \"${layout_variant}\"" "${SETTINGS}")" &&
    echo "${settings}" > "${SETTINGS}" ||
    abort 'Failed to save layout_variant setting.'

  log "Layout is set to ${keyboard_layout} ${layout_variant}."
}

# Asks the user to select keyboard switch options.
select_keyboard_options () {
  local options=''
  options="$(
    localectl --no-pager list-x11-keymap-options 2> /dev/null | awk '{
      print "{\"key\":\""$0"\",\"value\":\""$0"\"},"
    }'
  )"
  
  if has_failed; then
    abort 'Unable to list keyboard options.'
  fi

  # Remove extra comma delimiter from last element
  options="[${options:+${options::-1}}]"

  pick_one -n 'Select the keyboard options value:' "${options}" 'vertical' || abort
  is_not_given "${REPLY}" && abort 'User input is required.'

  local keyboard_options="${REPLY}"

  local settings=''
  settings="$(jq -er ".keyboard_options = \"${keyboard_options}\"" "${SETTINGS}")" &&
    echo "${settings}" > "${SETTINGS}" ||
    abort 'Failed to save keyboard_options setting.'

  log "Keyboard options is set to ${keyboard_options}."
}

# Asks the user to set the name of the host.
enter_host_name () {
  ask -n 'Enter the name of the host:' || abort
  is_not_given "${REPLY}" && abort 'User input is required.'

  while not_match "${REPLY}" '^[a-z][a-z0-9_-]+$'; do
    ask 'Please enter a valid host name:' || abort
    is_not_given "${REPLY}" && abort 'User input is required.'
  done

  local host_name="${REPLY}"

  local settings=''
  settings="$(jq -er ".host_name = \"${host_name}\"" "${SETTINGS}")" &&
    echo "${settings}" > "${SETTINGS}" ||
    abort 'Failed to save host_name setting.'

  log "Hostname is set to ${host_name}."
}

# Asks the user to set the name of the sudoer user.
enter_user_name () {
  ask -n 'Enter the name of the user:' || abort
  is_not_given "${REPLY}" && abort 'User input is required.'

  while not_match "${REPLY}" '^[a-z][a-z0-9_-]+$'; do
    ask 'Please enter a valid user name:' || abort
    is_not_given "${REPLY}" && abort 'User input is required.'
  done

  local user_name="${REPLY}"

  local settings=''
  settings="$(jq -er ".user_name = \"${user_name}\"" "${SETTINGS}")" &&
    echo "${settings}" > "${SETTINGS}" ||
    abort 'Failed to save user_name setting.'

  log "User name is set to ${user_name}."
}

# Asks the user to set the password of the sudoer user.
enter_user_password () {
  log -n 'Password valid chars: a-z A-Z 0-9 `~!@#$%^&*()=+{};:",.<>/?_-'
  ask_secret 'Enter the user password (at least 4 chars):' || abort
  is_not_given "${REPLY}" && abort '\nUser input is required.'

  while not_match "${REPLY}" '^[a-zA-Z0-9`~!@#\$%^&*()=+{};:",.<>/\?_-]{4,}$'; do
    ask_secret -n 'Please enter a valid password:' || abort
    is_not_given "${REPLY}" && abort '\nUser input is required.'
  done

  local password="${REPLY}"

  ask_secret -n 'Re-type the given password:' || abort
  is_not_given "${REPLY}" && abort '\nUser input is required.'

  while not_equals "${REPLY}" "${password}"; do
    ask_secret -n 'Not matched, please re-type the given password:' || abort
    is_not_given "${REPLY}" && abort '\nUser input is required.'
  done

  local settings=''
  settings="$(jq -er ".user_password = \"${password}\"" "${SETTINGS}")" &&
    echo "${settings}" > "${SETTINGS}" ||
    abort 'Failed to save user_password setting.'

  log -n 'User password is set successfully.'
}

# Asks the user to set the password of the root user.
enter_root_password () {
  log -n 'Password valid chars: a-z A-Z 0-9 `~!@#$%^&*()=+{};:",.<>/?_-'
  ask_secret 'Enter the root password (at least 4 chars):' || abort
  is_not_given "${REPLY}" && abort '\nUser input is required.'

  while not_match "${REPLY}" '^[a-zA-Z0-9`~!@#\$%^&*()=+{};:",.<>/\?_-]{4,}$'; do
    ask_secret -n 'Please enter a valid password:' || abort
    is_not_given "${REPLY}" && abort '\nUser input is required.'
  done

  local password="${REPLY}"

  ask_secret -n 'Re-type the given password:' || abort
  is_not_given "${REPLY}" && abort '\nUser input is required.'

  while not_equals "${REPLY}" "${password}"; do
    ask_secret -n 'Not matched, please re-type the given password:' || abort
    is_not_given "${REPLY}" && abort '\nUser input is required.'
  done

  local settings=''
  settings="$(jq -er ".root_password = \"${password}\"" "${SETTINGS}")" &&
    echo "${settings}" > "${SETTINGS}" ||
    abort 'Failed to save root_password setting.'

  log -n 'Root password is set successfully.'
}

# Asks the user which linux kernel to install.
select_kernel () {
  local kernels=''
  kernels+='{"key": "stable", "value": "Stable"},'
  kernels+='{"key": "lts", "value": "LTS"}'
  kernels="[${kernels}]"

  pick_one -n 'Select which linux kernel to install:' "${kernels}" 'horizontal' || abort
  is_not_given "${REPLY}" && abort 'User input is required.'

  local kernel="${REPLY}"

  local settings=''
  settings="$(jq -er ".kernel = \"${kernel}\"" "${SETTINGS}")" &&
    echo "${settings}" > "${SETTINGS}" ||
    abort 'Failed to save kernel setting.'

  log "Linux kernel is set to ${kernel}."
}

# Report the collected installation settings.
report () {
  local query=''
  query='.user_password = "***" | .root_password = "***"'

  local settings=''
  settings="$(jq "${query}" "${SETTINGS}")" || abort

  log -n 'Installation properties have been set to:'
  log "${settings}"
}

while true; do
  # Initialize the settings file
  echo '{}' > "${SETTINGS}"

  select_disk &&
    opt_in_swap_space &&
    select_mirrors &&
    select_timezone &&
    select_locales &&
    select_keyboard_model &&
    select_keyboard_map &&
    select_keyboard_layout &&
    select_keyboard_options &&
    enter_host_name &&
    enter_user_name &&
    enter_user_password &&
    enter_root_password &&
    select_kernel &&
    report

  confirm -n 'Do you want to go with these settings?' || abort
  is_not_given "${REPLY}" && abort 'User input is required.'

  if is_yes "${REPLY}"; then
    break
  fi

  clear
done

log -n 'CAUTION, THIS IS THE LAST WARNING!'
log 'ALL data in the disk will be LOST FOREVER!'

confirm 'Do you want to proceed?' || abort

if is_not_given "${REPLY}"; then
  abort 'User input is required.'
fi

if is_no "${REPLY}"; then
  abort
fi

sleep 2
