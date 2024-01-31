#!/bin/bash

set -Eeo pipefail

source /opt/stack/scripts/utils.sh

# Resolves if UEFI mode is supported by the system.
is_uefi () {
  local uefi_mode='no'

  if directory_exists '/sys/firmware/efi/efivars'; then
    uefi_mode='yes'
  fi

  save_setting 'uefi_mode' "${uefi_mode}"

  log "UEFI mode is set to ${uefi_mode}"
}

# Resolves the vendor of the CPU installed CPU on the system.
resolve_cpu () {
  log 'Start detecting CPU vendor...'

  OUTPUT="$(
    lscpu 2>&1
  )" || fail

  local cpu_data="${OUTPUT}"

  local cpu_vendor='generic'

  if grep -Eq 'AuthenticAMD' <<< "${cpu_data}"; then
    cpu_vendor='amd'
  elif grep -Eq 'GenuineIntel' <<< "${cpu_data}"; then
    cpu_vendor='intel'
  fi

  save_setting 'cpu_vendor' "${cpu_vendor}"

  log "CPU vendor is set to ${cpu_vendor}"
}

# Resolves the vendor of the GPU installed on the system.
resolve_gpu () {
  log 'Start detecting GPU vendor...'

  OUTPUT="$(
    lspci 2>&1
  )" || fail

  local gpu_data="${OUTPUT}"

  local gpu_vendor='generic'

  if grep -Eq 'NVIDIA|GeForce' <<< ${gpu_data}; then
    gpu_vendor='nvidia'
  elif grep -Eq 'Radeon|AMD' <<< ${gpu_data}; then
    gpu_vendor='amd'
  elif grep -Eq 'Integrated Graphics Controller' <<< ${gpu_data}; then
    gpu_vendor='intel'
  elif grep -Eq 'Intel Corporation UHD' <<< ${gpu_data}; then
    gpu_vendor='intel'
  fi

  save_setting 'gpu_vendor' "${gpu_vendor}"

  log "GPU vendor is set to ${gpu_vendor}"
}

# Asks the user to install or not the synaptics touch drivers.
opt_in_synaptics () {
  confirm 'Do you want to install synaptics drivers?' || fail
  is_not_given "${REPLY}" && fail 'Installation has been canceled'

  local synaptics='no'

  if is_yes "${REPLY}"; then
    synaptics='yes'
  fi

  save_setting 'synaptics' "${synaptics}"

  log "Synaptics drivers are set to ${synaptics}"
}

# Resolves information and option of the system's hardware.
resolve_hardware () {
  log 'Started resolving system hardware...'

  is_uefi || fail

  OUTPUT="$(
    systemd-detect-virt 2>&1
  )"

  local vm_vendor="${OUTPUT}"

  if is_not_empty "${OUTPUT}" && not_equals "${OUTPUT}" 'none'; then
    save_setting 'vm' 'yes'
    save_setting 'vm_vendor' "${vm_vendor}"

    log 'Virtual machine is set to yes'
    log "Virtual machine vendor is set to ${vm_vendor}"
  else
    save_setting 'vm' 'no'

    resolve_cpu && resolve_gpu && opt_in_synaptics || fail
  fi

  log 'Hardware has been resolved successfully\n'
}

# Asks the user to select the installation disk.
select_disk () {
  local fields='name,path,type,size,rm,ro,tran,hotplug,state,'
  fields+='vendor,model,rev,serial,mountpoint,mountpoints,'
  fields+='label,uuid,fstype,fsver,fsavail,fsused,fsuse%'

  local query='[.blockdevices[]|select(.type == "disk")]'

  OUTPUT="$(
    lsblk -J -o "${fields}" 2>&1 | jq -cer "${query}" 2>&1
  )" || fail

  local disks="${OUTPUT}"

  local trim='.|gsub("^\\s+|\\s+$";"")'
  local vendor="\(.vendor|if . then .|${trim} else empty end)"

  local value=''
  value+="[\"${vendor}\", .rev, .serial, .size]|join(\" \")"
  value="\(${value}|if . != \"\" then \" [\(.|${trim})]\" else empty end)"
  value="\(.path)${value}"

  local query=''
  query="[.[]|{key: .path, value: \"${value}\"}]"

  OUTPUT="$(
    echo "${disks}" | jq -cer "${query}" 2>&1
  )" || fail

  disks="${OUTPUT}"

  pick_one 'Select the installation disk:' "${disks}" 'vertical' || fail
  is_not_given "${REPLY}" && fail 'Installation has been canceled'

  local disk="${REPLY}"

  log -t console "\nCAUTION, all data in \"${disk}\" will be lost!"
  confirm 'Do you want to proceed with this disk?' || fail

  if is_not_given "${REPLY}" || is_no "${REPLY}"; then
    fail 'Installation has been canceled'
  fi

  save_setting 'disk' "${disk}"

  confirm 'Is this disk an SSD drive?' || fail
  is_not_given "${REPLY}" && fail 'Installation has been canceled'

  if is_yes "${REPLY}"; then
    save_setting 'is_ssd' 'yes'
  else
    save_setting 'is_ssd' 'no'
  fi

  OUTPUT="$(
    lsblk -dn --discard -o DISC-GRAN,DISC-MAX "${disk}" 2>&1
  )" || fail

  local discards="${OUTPUT}"

  if match "${discards}" ' *[1-9]+[TGMB] *[1-9]+[TGMB] *'; then
    confirm 'Do you want to enable trim on this disk?' || fail
    is_not_given "${REPLY}" && fail 'Installation has been canceled'

    if is_yes "${REPLY}"; then
      save_setting 'trim_disk' 'yes'
    else
      save_setting 'trim_disk' 'no'
    fi
  else
    save_setting 'trim_disk' 'no'
  fi

  log "Installation disk is set to block device ${disk}\n"
}

# Asks the user to enable or not the swap space.
opt_in_swap_space () {
  confirm 'Do you want to enable swap space?' || fail
  is_not_given "${REPLY}" && fail 'Installation has been canceled'

  if is_no "${REPLY}"; then
    save_setting 'swap_on' 'no'
    log 'Swap is set to off'

    return 0
  fi

  save_setting 'swap_on' 'yes'

  ask 'Enter the size of the swap space in GBs:' || fail

  while is_not_integer "${REPLY}" '[1,]'; do
    log -t console ' Swap space size should be a positive integer'
    ask ' Please enter a valid swap space size in GBs:' || fail
  done

  local swap_size="${REPLY}"

  save_setting 'swap_size' "${swap_size}"

  local swap_types=''
  swap_types+='{"key": "file", "value":"File"},'
  swap_types+='{"key": "partition", "value":"Partition"}'
  swap_types="[${swap_types}]"

  pick_one 'Which type of swap to setup:' "${swap_types}" 'horizontal' || fail
  is_not_given "${REPLY}" && fail 'Installation has been canceled'

  local swap_type="${REPLY}"

  save_setting 'swap_type' "${swap_type}"

  log "Swap type is set to ${swap_type}"
  log "Swap size is set to ${swap_size}GB\n"
}

# Asks the user to select the mirror countries used for installation and updates.
select_mirrors () {
  OUTPUT="$(
    reflector --list-countries 2>&1 | tail -n +3 | awk '{
      match($0, /(.*)([A-Z]{2})\s+([0-9]+)/, a)
      gsub(/[ \t]+$/, "", a[1])

      frm="{\"key\": \"%s\", \"value\": \"%s\"},"
      printf frm, a[2], a[1]" ["a[3]"]"
    }' 2>&1
  )" || fail

  local mirrors="${OUTPUT}"

  # Remove the extra comma from the last element
  mirrors="[${mirrors:+${mirrors::-1}}]"

  pick_many 'Select mirror countries:' "${mirrors}" 'vertical' || fail
  is_not_given "${REPLY}" && fail 'Installation has been canceled'

  mirrors="${REPLY}"

  save_setting 'mirrors' "${mirrors}"

  log "Mirror countries are set to ${mirrors}\n"
}

# Asks the user to select the system's timezone.
select_timezone () {
  OUTPUT="$(
    timedatectl list-timezones 2>&1 | awk '{
      print "{\"key\":\""$0"\",\"value\":\""$0"\"},"
    }' 2>&1
  )" || fail

  local timezones="${OUTPUT}"

  # Remove the extra comma after the last array element
  timezones="[${timezones:+${timezones::-1}}]"

  pick_one 'Select the system timezone:' "${timezones}" 'vertical' || fail
  is_not_given "${REPLY}" && fail 'Installation has been canceled'

  local timezone="${REPLY}"

  save_setting 'timezone' "${timezone}"

  log "Timezone is set to ${timezone}\n"
}

# Asks the user to select which locales to install.
select_locales () {
  OUTPUT="$(
    cat /etc/locale.gen | tail -n +24 | grep -E '^\s*#.*' | tr -d '#' | trim | awk '{
      print "{\"key\":\""$0"\",\"value\":\""$0"\"},"
    }' 2>&1
  )" || fail

  local locales="${OUTPUT}"
  
  # Removes the last comma delimiter from the last element
  locales="[${locales:+${locales::-1}}]"

  pick_many 'Select system locales by order:' "${locales}" 'vertical' || fail
  is_not_given "${REPLY}" && fail 'Installation has been canceled'

  locales="${REPLY}"

  save_setting 'locales' "${locales}"

  log "Locales are set to ${locales}\n"
}

# Asks the user to select the keyboard model.
select_keyboard_model () {
  # TODO: localectl needs xorg deps to provide x11 kb models
  save_setting 'keyboard_model' 'pc105'
  return 0

  OUTPUT="$(
    localectl --no-pager list-x11-keymap-models 2>&1 | awk '{
      print "{\"key\":\""$1"\",\"value\":\""$1"\"},"
    }' 2>&1
  )" || fail

  local models="${OUTPUT}"

  # Remove the extra comma delimiter from the last element
  models="[${models:+${models::-1}}]"

  pick_one 'Select a keyboard model:' "${models}" 'vertical' || fail
  is_not_given "${REPLY}" && fail 'Installation has been canceled'

  local keyboard_model="${REPLY}"

  save_setting 'keyboard_model' "${keyboard_model}"

  log "Keyboard model is set to ${keyboard_model}\n"
}

# Asks the user to select the keyboard map.
select_keyboard_map () {
  OUTPUT="$(
    localectl --no-pager list-keymaps 2>&1 | awk '{
      print "{\"key\":\""$0"\",\"value\":\""$0"\"},"
    }' 2>&1
  )" || fail

  local maps="${OUTPUT}"
  
  # Remove extra comma delimiter from the last element
  maps="[${maps:+${maps::-1}}]"

  pick_one 'Select a keyboard map:' "${maps}" 'vertical' || fail
  is_not_given "${REPLY}" && fail 'Installation has been canceled'

  local keyboard_map="${REPLY}"

  save_setting 'keyboard_map' "${keyboard_map}"

  log "Keyboard map is set to ${keyboard_map}\n"
}

# Asks the user to select keyboard layouts.
select_keyboard_layouts () {
  # TODO: localectl needs xorg deps to provide x11 kb layouts
  save_setting 'keyboard_layouts' '["us", "gr", "de"]'
  return 0

  OUTPUT="$(
    localectl --no-pager list-x11-keymap-layouts 2>&1 | awk '{
      print "{\"key\":\""$0"\",\"value\":\""$0"\"},"
    }' 2>&1
  )" || fail

  local layouts="${OUTPUT}"
  
  # Remove the extra comma delimiter from last element
  layouts="[${layouts:+${layouts::-1}}]"

  pick_many 'Select keyboard layouts:' "${layouts}" 'vertical' || fail
  is_not_given "${REPLY}" && fail 'Installation has been canceled'

  keyboard_layouts="${REPLY}"

  save_setting 'keyboard_layouts' "${keyboard_layouts}"

  log "Keyboard layouts are set to ${keyboard_layouts}\n"
}

# Asks the user to select keyboard switch options.
select_keyboard_options () {
  # TODO: localectl needs xorg deps to provide x11 kb options
  save_setting 'keyboard_options' 'grp:alt_shift_toggle'
  return 0

  OUTPUT="$(
    localectl --no-pager list-x11-keymap-options 2>&1 | awk '{
      print "{\"key\":\""$0"\",\"value\":\""$0"\"},"
    }' 2>&1
  )" || fail

  local options="${OUTPUT}"

  # Remove extra comma delimiter from last element
  options="[${options:+${options::-1}}]"

  pick_one 'Select the keyboard options value:' "${options}" 'vertical' || fail
  is_not_given "${REPLY}" && fail 'Installation has been canceled'

  keyboard_options="${REPLY}"

  save_setting 'keyboard_options' "${keyboard_options}"

  log "Keyboard layouts are set to ${keyboard_options}\n"
}

# Asks the user to set the name of the host.
enter_host_name () {
  ask 'Enter the name of the host:' || fail

  while not_match "${REPLY}" '^[a-z][a-z0-9_-]+$'; do
    log -t console ' Host name should start with a latin char'
    ask ' Please enter a valid host name:' || fail
  done

  local host_name="${REPLY}"

  save_setting 'host_name' "${host_name}"

  log "Hostname is set to ${host_name}\n"
}

# Asks the user to set the name of the sudoer user.
enter_user_name () {
  ask 'Enter the name of the user:' || fail

  while not_match "${REPLY}" '^[a-z][a-z0-9_-]+$'; do
    log -t console ' Host name should start with a latin char'
    ask ' Please enter a valid user name:' || fail
  done

  local user_name="${REPLY}"

  save_setting 'user_name' "${user_name}"

  log "User name is set to ${user_name}\n"
}

# Asks the user to set the password of the sudoer user.
enter_user_password () {
  ask_secret 'Enter the user password:' || fail

  while not_match "${REPLY}" '^[a-zA-Z0-9@&!#%\$_-]{4,}$'; do
    log -t console ' Password must be at least 4 chars of a-z A-Z 0-9 @&!#%\$_-'
    ask_secret ' Please enter a stronger user password:' || fail
  done

  local password="${REPLY}"

  ask_secret 'Re-type the given password:' || fail

  while not_equals "${REPLY}" "${password}"; do
    ask_secret ' Not matched, please re-type the given password:' || fail
  done

  save_setting 'user_password' "${password}"

  log 'User password is set successfully\n'
}

# Asks the user to set the password of the root user.
enter_root_password () {
  ask_secret 'Enter the root password:' || fail

  while not_match "${REPLY}" '^[a-zA-Z0-9@&!#%\$_-]{4,}$'; do
    log -t console ' Password must be at least 4 chars of a-z A-Z 0-9 @&!#%\$_-'
    ask_secret ' Please enter a stronger root password:' || fail
  done

  local password="${REPLY}"

  ask_secret 'Re-type the given password:' || fail

  while not_equals "${REPLY}" "${password}"; do
    ask_secret ' Not matched, please re-type the given password:' || fail
  done

  save_setting 'root_password' "${password}"

  log 'Root password is set successfully\n'
}

# Asks the user which linux kernels to install.
select_kernels () {
  local kernels=''
  kernels+='{"key": "stable", "value": "Stable"},'
  kernels+='{"key": "lts", "value": "LTS"}'
  kernels="[${kernels}]"

  pick_many 'Select which linux kernels to install:' "${kernels}" 'horizontal' || fail
  is_not_given "${REPLY}" && fail 'Installation has been canceled'

  kernels="${REPLY}"

  save_setting 'kernels' "${kernels}"

  log "Linux kernels are set to ${kernels}\n"
}

# Report the collected installation settings.
report () {
  local query=''
  query='.user_password = "***" | .root_password = "***"'

  local settings=''
  settings="$(get_settings | jq "${query}")" || fail

  log '\nInstallation settings have been set to:'
  log "${settings}"
}

log '\nStarting to collect the installation settings...'

while true; do
  init_settings &&
    resolve_hardware &&
    select_disk &&
    opt_in_swap_space &&
    select_mirrors &&
    select_timezone &&
    select_locales &&
    select_keyboard_model &&
    select_keyboard_map &&
    select_keyboard_layouts &&
    select_keyboard_options &&
    enter_host_name &&
    enter_user_name &&
    enter_user_password &&
    enter_root_password &&
    select_kernels &&
    report

  confirm 'Do you agree to go with these settings?' || fail
  is_not_given "${REPLY}" && fail 'Installation has been canceled'

  if is_yes "${REPLY}"; then
    break
  fi

  clear
  log 'Starting another run to collect new installation settings...'
done

log -t console '\nCAUTION, THIS IS THE LAST WARNING!'
log -t console 'ALL data in the disk will be LOST FOREVER!'

confirm 'Do you want to proceed?' || fail

if is_not_given "${REPLY}" || is_no "${REPLY}"; then
  fail 'Installation has been canceled'
fi

sleep 3
