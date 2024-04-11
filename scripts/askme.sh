#!/bin/bash

set -Eeo pipefail

source /opt/stack/scripts/utils.sh

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
    log 'Unable to list disk block devices'
    exit 1
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
    log 'Failed to parse disks data'
    exit 1
  fi

  pick_one 'Select the installation disk:' "${disks}" 'vertical' || exit 1
  is_not_given "${REPLY}" && log 'User input is required' && exit 1

  local disk="${REPLY}"

  log "\nCAUTION, all data in \"${disk}\" will be lost!"
  confirm 'Do you want to proceed with this disk?' || exit 1

  if is_not_given "${REPLY}"; then
    log 'User input is required'
    exit 1
  fi

  if is_no "${REPLY}"; then
    exit 1
  fi

  save_setting 'disk' "\"${disk}\""

  log "Installation disk set to block device ${disk}"
}

# Asks the user to enable or not the swap space.
opt_in_swap_space () {
  confirm '\nDo you want to enable swap space?' || exit 1
  is_not_given "${REPLY}" && log 'User input is required' && exit 1

  if is_no "${REPLY}"; then
    save_setting 'swap_on' '"no"'

    log 'Swap is set to off'
    return 0
  fi

  save_setting 'swap_on' '"yes"'

  log 'Swap is set to yes'

  ask 'Enter the size of the swap space in GBs:'
  is_not_given "${REPLY}" && log 'User input is required' && exit 1

  while is_not_integer "${REPLY}" '[1,]'; do
    ask 'Please enter a valid swap space size in GBs:'
    is_not_given "${REPLY}" && log 'User input is required' && exit 1
  done

  local swap_size="${REPLY}"

  save_setting 'swap_size' "${swap_size}"

  log "Swap size is set to ${swap_size}GB"

  local swap_types=''
  swap_types+='{"key": "file", "value":"File"},'
  swap_types+='{"key": "partition", "value":"Partition"}'
  swap_types="[${swap_types}]"

  pick_one 'Which type of swap to setup:' "${swap_types}" 'horizontal' || exit 1
  is_not_given "${REPLY}" && log 'User input is required' && exit 1

  local swap_type="${REPLY}"

  save_setting 'swap_type' "\"${swap_type}\""

  log "Swap type is set to ${swap_type}"
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
    log 'Unable to fetch package databases mirrors'
    exit 1
  fi

  # Remove the extra comma from the last element
  mirrors="[${mirrors:+${mirrors::-1}}]"

  pick_many '\nSelect package databases mirrors:' "${mirrors}" 'vertical' || exit 1
  is_not_given "${REPLY}" && log 'User input is required' && exit 1

  mirrors="${REPLY}"

  save_setting 'mirrors' "${mirrors}"

  log "Package databases mirrors are set to ${mirrors}"
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
    log 'Unable to list timezones'
    exit 1
  fi

  # Remove the extra comma after the last array element
  timezones="[${timezones:+${timezones::-1}}]"

  pick_one '\nSelect the system timezone:' "${timezones}" 'vertical' || exit 1
  is_not_given "${REPLY}" && log 'User input is required' && exit 1

  local timezone="${REPLY}"

  save_setting 'timezone' "\"${timezone}\""

  log "Timezone is set to ${timezone}"
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
    log 'Unable to list the locales'
    exit 1
  fi
  
  # Removes the last comma delimiter from the last element
  locales="[${locales:+${locales::-1}}]"

  pick_many '\nSelect system locales by order:' "${locales}" 'vertical' || exit 1
  is_not_given "${REPLY}" && log 'User input is required' && exit 1

  locales="${REPLY}"

  save_setting 'locales' "${locales}"

  log "Locales are set to ${locales}"
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
    log 'Unable to list keyboard models'
    exit 1
  fi

  # Remove the extra comma delimiter from the last element
  models="[${models:+${models::-1}}]"

  pick_one '\nSelect a keyboard model:' "${models}" 'vertical' || exit 1
  is_not_given "${REPLY}" && log 'User input is required' && exit 1

  local keyboard_model="${REPLY}"

  save_setting 'keyboard_model' "\"${keyboard_model}\""

  log "Keyboard model is set to ${keyboard_model}"
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
    log 'Unable to list keyboard maps'
    exit 1
  fi
  
  # Remove extra comma delimiter from the last element
  maps="[${maps:+${maps::-1}}]"

  pick_one '\nSelect a keyboard map:' "${maps}" 'vertical' || exit 1
  is_not_given "${REPLY}" && log 'User input is required' && exit 1

  local keyboard_map="${REPLY}"

  save_setting 'keyboard_map' "\"${keyboard_map}\""

  log "Keyboard map is set to ${keyboard_map}"
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
    log 'Unable to list keyboard layouts'
    exit 1
  fi
  
  # Remove the extra comma delimiter from last element
  layouts="[${layouts:+${layouts::-1}}]"

  pick_one '\nSelect a keyboard layout:' "${layouts}" 'vertical' || exit 1
  is_not_given "${REPLY}" && log 'User input is required' && exit 1

  local keyboard_layout="${REPLY}"

  save_setting 'keyboard_layout' "\"${keyboard_layout}\""

  local variants='{"key": "default", "value": "default"},'
  variants+="$(
    localectl --no-pager list-x11-keymap-variants "${keyboard_layout}" 2> /dev/null  | awk '{
      print "{\"key\":\""$0"\",\"value\":\""$0"\"},"
    }'
  )"
  
  if has_failed; then
    log 'Unable to list layout variants'
    exit 1
  fi
  
  # Remove the extra comma delimiter from last element
  variants="[${variants:+${variants::-1}}]"

  pick_one "\nSelect a ${keyboard_layout} layout variant:" "${variants}" vertical || exit 1
  is_not_given "${REPLY}" && log 'User input is required' && exit 1

  local layout_variant="${REPLY}"

  save_setting 'layout_variant' "\"${layout_variant}\""

  log "Layout is set to ${keyboard_layout} ${layout_variant}"
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
    log 'Unable to list keyboard options'
    exit 1
  fi

  # Remove extra comma delimiter from last element
  options="[${options:+${options::-1}}]"

  pick_one '\nSelect the keyboard options value:' "${options}" 'vertical' || exit 1
  is_not_given "${REPLY}" && log 'User input is required' && exit 1

  local keyboard_options="${REPLY}"

  save_setting 'keyboard_options' "\"${keyboard_options}\""

  log "Keyboard options is set to ${keyboard_options}"
}

# Asks the user to set the name of the host.
enter_host_name () {
  echo ''
  ask 'Enter the name of the host:'
  is_not_given "${REPLY}" && log 'User input is required' && exit 1

  while not_match "${REPLY}" '^[a-z][a-z0-9_-]+$'; do
    ask 'Please enter a valid host name:'
    is_not_given "${REPLY}" && log 'User input is required' && exit 1
  done

  local host_name="${REPLY}"

  save_setting 'host_name' "\"${host_name}\""

  log "Hostname is set to ${host_name}"
}

# Asks the user to set the name of the sudoer user.
enter_user_name () {
  echo ''
  ask 'Enter the name of the user:'
  is_not_given "${REPLY}" && log 'User input is required' && exit 1

  while not_match "${REPLY}" '^[a-z][a-z0-9_-]+$'; do
    ask 'Please enter a valid user name:'
    is_not_given "${REPLY}" && log 'User input is required' && exit 1
  done

  local user_name="${REPLY}"

  save_setting 'user_name' "\"${user_name}\""

  log "User name is set to ${user_name}"
}

# Asks the user to set the password of the sudoer user.
enter_user_password () {
  echo ''
  ask_secret 'Enter the user password:'
  is_not_given "${REPLY}" && log 'User input is required' && exit 1

  while not_match "${REPLY}" '^[a-zA-Z0-9@&!#%\$_-]{4,}$'; do
    ask_secret 'Please enter a stronger user password:'
    is_not_given "${REPLY}" && log 'User input is required' && exit 1
  done

  local password="${REPLY}"

  ask_secret 'Re-type the given password:'
  is_not_given "${REPLY}" && log 'User input is required' && exit 1

  while not_equals "${REPLY}" "${password}"; do
    ask_secret 'Not matched, please re-type the given password:'
    is_not_given "${REPLY}" && log 'User input is required' && exit 1
  done

  save_setting 'user_password' "\"${password}\""

  log 'User password is set successfully'
}

# Asks the user to set the password of the root user.
enter_root_password () {
  echo ''
  ask_secret 'Enter the root password:'
  is_not_given "${REPLY}" && log 'User input is required' && exit 1

  while not_match "${REPLY}" '^[a-zA-Z0-9@&!#%\$_-]{4,}$'; do
    ask_secret 'Please enter a stronger root password:'
    is_not_given "${REPLY}" && log 'User input is required' && exit 1
  done

  local password="${REPLY}"

  ask_secret 'Re-type the given password:'
  is_not_given "${REPLY}" && log 'User input is required' && exit 1

  while not_equals "${REPLY}" "${password}"; do
    ask_secret 'Not matched, please re-type the given password:'
    is_not_given "${REPLY}" && log 'User input is required' && exit 1
  done

  save_setting 'root_password' "\"${password}\""

  log 'Root password is set successfully'
}

# Asks the user which linux kernel to install.
select_kernel () {
  local kernels=''
  kernels+='{"key": "stable", "value": "Stable"},'
  kernels+='{"key": "lts", "value": "LTS"}'
  kernels="[${kernels}]"

  pick_one '\nSelect which linux kernel to install:' "${kernels}" 'horizontal' || exit 1
  is_not_given "${REPLY}" && log 'User input is required' && exit 1

  local kernel="${REPLY}"

  save_setting 'kernel' "\"${kernel}\""

  log "Linux kernel is set to ${kernel}"
}

# Report the collected installation settings.
report () {
  local query=''
  query='.user_password = "***" | .root_password = "***"'

  local settings=''
  settings="$(get_settings | jq "${query}")"
  
  if has_failed; then
    log 'Unable to read settings'
    exit 1
  fi

  log '\nInstallation properties have been set to:'
  log "${settings}"
}

while true; do
  init_settings &&
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

  confirm '\nDo you want to go with these settings?' || exit 1
  is_not_given "${REPLY}" && log 'User input is required' && exit 1

  if is_yes "${REPLY}"; then
    break
  fi

  clear
done

log '\nCAUTION, THIS IS THE LAST WARNING!'
log 'ALL data in the disk will be LOST FOREVER!'

confirm 'Do you want to proceed?' || exit 1

if is_not_given "${REPLY}"; then
  log 'User input is required'
  exit 1
fi

if is_no "${REPLY}"; then
  exit 1
fi

sleep 2
