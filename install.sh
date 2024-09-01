#!/bin/bash

set -Eeo pipefail

source src/commons/input.sh
source src/commons/error.sh
source src/commons/logger.sh
source src/commons/validators.sh
source src/commons/text.sh
source src/commons/math.sh

SETTINGS=./settings.json

BAR_FORMAT='{desc:10}  {percentage:3.0f}%|{bar}|  ET{elapsed}'

# Initializes the installer.
init () {
  # Reset possibly existing log files
  rm -rf /var/log/stack
  mkdir -p /var/log/stack
}

# Shows the welcome screen to the user.
welcome () {
  clear

  log '░░░█▀▀░▀█▀░█▀█░█▀▀░█░█░░░'
  log '░░░▀▀█░░█░░█▀█░█░░░█▀▄░░░'
  log '░░░▀▀▀░░▀░░▀░▀░▀▀▀░▀░▀░░░'

  log -n 'Welcome to the Stack Linux installer.'
  log 'Base your development stack on Arch Linux.'

  confirm 'Do you want to proceed?' || abort

  if is_not_given "${REPLY}"; then
    abort 'User input is required.'
  fi

  if is_no "${REPLY}"; then
    abort 'Sure, maybe next time.'
  fi
}

# Asks the user the installation settings in order
# to collect all the required props to install the
# new system.
ask () {
  local select_disk
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

    disks="$(echo "${disks}" | jq -cer "${query}")"

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

  local opt_in_swap_space
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

  local select_mirrors
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

  local select_timezone
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

  local select_locales
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

  local select_keyboard_model
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

  local select_keyboard_map
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

  local select_keyboard_layout
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

  local select_keyboard_options
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

  local enter_host_name
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

  local enter_user_name
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

  local enter_user_password
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

  local enter_root_password
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

  local select_kernel
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
      select_kernel

    confirm -n 'Do you want to ask for settings again?' || abort
    is_not_given "${REPLY}" && abort 'User input is required.'

    if is_no "${REPLY}"; then
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
}

# Detects some hardware informations to collect extra
# required props to install the new system.
detect () {
  local is_uefi
  is_uefi () {
    local uefi_mode='no'

    if directory_exists '/sys/firmware/efi/efivars'; then
      uefi_mode='yes'
    fi

    local settings=''
    settings="$(jq -er ".uefi_mode = \"${uefi_mode}\"" "${SETTINGS}")" &&
      echo "${settings}" > "${SETTINGS}" ||
      abort ERROR 'Failed to save uefi_mode setting.'

    log INFO "UEFI mode is set to ${uefi_mode}."
  }

  local is_virtual_machine
  is_virtual_machine () {
    local vm_vendor=''
    vm_vendor="$(
      systemd-detect-virt 2>&1
    )"

    if is_not_empty "${vm_vendor}" && not_equals "${vm_vendor}" 'none'; then
      local settings=''
      settings="$(jq -er '.vm = "yes"' "${SETTINGS}")" &&
        echo "${settings}" > "${SETTINGS}" ||
        abort ERROR 'Failed to save vm setting.'

      local settings=''
      settings="$(jq -er ".vm_vendor = \"${vm_vendor}\"" "${SETTINGS}")" &&
        echo "${settings}" > "${SETTINGS}" ||
        abort ERROR 'Failed to save vm_vendor setting.'

      log INFO 'Virtual machine is set to yes.'
      log INFO "Virtual machine vendor is set to ${vm_vendor}."
    else
      local settings=''
      settings="$(jq -er '.vm = "no"' "${SETTINGS}")" &&
        echo "${settings}" > "${SETTINGS}" ||
        abort ERROR 'Failed to save vm setting.'
    fi
  }

  local resolve_cpu
  resolve_cpu () {
    local cpu_data=''
    cpu_data="$(
      lscpu 2>&1
    )" || abort ERROR 'Unable to read CPU data.'

    local cpu_vendor='generic'

    if grep -Eq 'AuthenticAMD' <<< "${cpu_data}"; then
      cpu_vendor='amd'
    elif grep -Eq 'GenuineIntel' <<< "${cpu_data}"; then
      cpu_vendor='intel'
    fi

    local settings=''
    settings="$(jq -er ".cpu_vendor = \"${cpu_vendor}\"" "${SETTINGS}")" &&
      echo "${settings}" > "${SETTINGS}" ||
      abort ERROR 'Failed to save cpu_vendor setting.'

    log INFO "CPU vendor is set to ${cpu_vendor}."
  }

  local resolve_gpu
  resolve_gpu () {
    local gpu_data=''
    gpu_data="$(
      lspci 2>&1
    )" || abort ERROR 'Unable to read GPU data.'

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

    local settings=''
    settings="$(jq -er ".gpu_vendor = \"${gpu_vendor}\"" "${SETTINGS}")" &&
      echo "${settings}" > "${SETTINGS}" ||
      abort ERROR 'Failed to save gpu_vendor setting.'

    log INFO "GPU vendor is set to ${gpu_vendor}."
  }

  local is_disk_trimmable
  is_disk_trimmable () {
    local disk=''
    disk="$(jq -cer '.disk' "${SETTINGS}")" ||
      abort ERROR 'Unable to read disk setting.'

    local discards=''
    discards="$(
      lsblk -dn --discard -o DISC-GRAN,DISC-MAX "${disk}" 2>&1
    )" || abort ERROR 'Unable to list disk block devices.'

    local trim_disk='no'

    if match "${discards}" ' *[1-9]+[TGMB] *[1-9]+[TGMB] *'; then
      trim_disk='yes'
    fi

    local settings=''
    settings="$(jq -er ".trim_disk = \"${trim_disk}\"" "${SETTINGS}")" &&
      echo "${settings}" > "${SETTINGS}" ||
      abort ERROR 'Failed to save trim_disk setting.'

    log INFO "Disk trim mode is set to ${trim_disk}."
  }

  is_uefi &&
    is_virtual_machine &&
    resolve_cpu &&
    resolve_gpu &&
    is_disk_trimmable
}

# Reports all the installation settings set by the user.
report () {
  local log_file="/var/log/stack/report.log"

  local query=''
  query='.user_password = "***" | .root_password = "***"'

  local settings=''
  settings="$(jq "${query}" "${SETTINGS}")"

  if has_failed; then
    log ERROR 'Unable to read installation settings.' >> "${log_file}"
    abort 'Unable to read installation settings.'
  fi

  log -n 'Installation settings set to:' > "${log_file}"
  log "${settings}\n" >> "${log_file}"
}

# Executes a preparation task script with the given file name.
# Arguments:
#  file_name: the name of a task script
run () {
  local file_name="${1}"

  local script_file="src/installer/${file_name}.sh"
  local log_file="/var/log/stack/${file_name}.log"

  local total=0
  total=$(grep 'resolve [0-9].*' "${script_file}" | cut -d ' ' -f 2)

  if has_failed; then
    log ERROR "Unable to read the expected output of ${file_name}.sh." >> "${log_file}"
    abort 'A fatal error has been occurred.'
  fi

  bash "${script_file}" 2>&1 |
    tee -a "${log_file}" 2>&1 |
    tqdm --desc "${file_name^}:" --ncols 50 \
      --bar-format "${BAR_FORMAT}" --total ${total} >> "${log_file}.tqdm"

  if has_failed; then
    log ERROR "Script ${file_name}.sh has failed." >> "${log_file}"
    abort 'A fatal error has been occurred.'
  fi
}

# Executes an installation script with the given file name via
# chroot into the installation disk as root or sudoer user.
# Arguments:
#  file_name: the name of an installation script
install () {
  local file_name="${1}"

  local script_file="src/installer/${file_name}.sh"
  local log_file="/mnt/var/log/stack/${file_name}.log"

  local user_name='root'

  # Execute user related tasks as sudoer user
  if match "${file_name}" '^(sdkits|apps)$'; then
    user_name="$(jq -cer '.user_name' "${SETTINGS}")"

    if has_failed; then
      log ERROR 'Unable to read the user_name setting.' >> "${log_file}"
      abort 'Unable to read user_name setting.'
    fi
  fi

  local total=0
  total=$(grep 'resolve [0-9].*' "${script_file}" | cut -d ' ' -f 2)

  if has_failed; then
    log ERROR "Unable to read the expected output of ${file_name}.sh." >> "${log_file}"
    abort 'A fatal error has been occurred.'
  fi

  arch-chroot /mnt runuser -u "${user_name}" -- "${script_file}" 2>&1 |
    tee -a "${log_file}" 2>&1 |
    tqdm --desc "${file_name^}:" --ncols 50 \
      --bar-format "${BAR_FORMAT}" --total ${total} >> "${log_file}.tqdm"
  
  if has_failed; then
    log ERROR "Script ${file_name}.sh has failed." >> "${log_file}"
    abort 'A fatal error has been occurred.'
  fi
}

# Restarts the system.
restart () {
  # Copy the installation log files to the new system
  cp /var/log/stack/* /mnt/var/log/stack

  # Append all logs in chronological order
  cat /mnt/var/log/stack/detection.log \
    /mnt/var/log/stack/report.log \
    /mnt/var/log/stack/diskpart.log \
    /mnt/var/log/stack/bootstrap.log \
    /mnt/var/log/stack/system.log \
    /mnt/var/log/stack/sdkits.log \
    /mnt/var/log/stack/apps.log \
    /mnt/var/log/stack/cleaner.log >> /mnt/var/log/stack/all.log

  # Clean redundant log files from live media
  rm -rf /var/log/stack
  
  log -n 'Installation process has been completed.'
  log 'Rebooting the system in 15 secs...'

  sleep 15
  umount -R /mnt || log 'Ignoring busy mount points.'
  reboot
}

if file_not_in_directory "${0}" "${PWD}"; then
  abort ERROR 'Unable to run script out of its parent directory.'
fi

init &&
  welcome &&
  ask &&
  detect &&
  report &&
  run diskpart &&
  run bootstrap &&
  install system &&
  install sdkits &&
  install apps &&
  run cleaner &&
  restart
