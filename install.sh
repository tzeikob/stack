#!/bin/bash

set -Eeo pipefail

if [[ "$(dirname "$(realpath -s "${0}")")" != "${PWD}" ]]; then
  echo 'Unable to run script out of its parent directory.'
  exit 1
fi

source src/commons/input.sh
source src/commons/error.sh
source src/commons/logger.sh
source src/commons/validators.sh
source src/commons/text.sh
source src/commons/math.sh

LOGS_HOME=/var/log/stack
LOG_FILE="${LOGS_HOME}/install.log"
SETTINGS_FILE=./settings.json


# Initializes the installer.
init () {
  # Reset logs
  mkdir -p "${LOGS_HOME}"
  echo '' > "${LOG_FILE}"

  # Initialize settings file
  echo '{}' > "${SETTINGS_FILE}"
}

# Shows the welcome screen to the user.
welcome () {
  clear

  log '░░░█▀▀░▀█▀░█▀█░█▀▀░█░█░░░'
  log '░░░▀▀█░░█░░█▀█░█░░░█▀▄░░░'
  log '░░░▀▀▀░░▀░░▀░▀░▀▀▀░▀░▀░░░'

  log -n 'Welcome to the Stack Linux installer.'
  log 'Base your development stack on Arch Linux.'

  confirm -n 'Do you want to proceed?' || abort
  is_not_given "${REPLY}" && abort 'User input is required.'

  if is_no "${REPLY}"; then
    abort 'Sure, maybe next time!'
  fi
}

# Detects any hardware data to collect extra
# required props to install the new system.
detect () {
  local is_uefi
  is_uefi () {
    local uefi_mode='no'

    if directory_exists '/sys/firmware/efi/efivars'; then
      uefi_mode='yes'
    fi

    local settings=''
    settings="$(jq -er ".uefi_mode = \"${uefi_mode}\"" "${SETTINGS_FILE}")" &&
      echo "${settings}" > "${SETTINGS_FILE}" ||
      abort 'Failed to save uefi_mode setting.'
  }

  local is_virtual_machine
  is_virtual_machine () {
    local vm_vendor=''
    vm_vendor="$(systemd-detect-virt 2>&1)"

    if is_not_empty "${vm_vendor}" && not_equals "${vm_vendor}" 'none'; then
      local settings=''
      settings="$(jq -er '.vm = "yes"' "${SETTINGS_FILE}")" &&
        echo "${settings}" > "${SETTINGS_FILE}" ||
        abort 'Failed to save vm setting.'

      local settings=''
      settings="$(jq -er ".vm_vendor = \"${vm_vendor}\"" "${SETTINGS_FILE}")" &&
        echo "${settings}" > "${SETTINGS_FILE}" ||
        abort 'Failed to save vm_vendor setting.'
    else
      local settings=''
      settings="$(jq -er '.vm = "no"' "${SETTINGS_FILE}")" &&
        echo "${settings}" > "${SETTINGS_FILE}" ||
        abort 'Failed to save vm setting.'
    fi
  }

  local resolve_cpu
  resolve_cpu () {
    local cpu_data=''
    cpu_data="$(lscpu 2>&1)" ||
      abort 'Unable to detect CPU data.'

    local cpu_vendor='generic'

    if grep -Eq 'AuthenticAMD' <<< "${cpu_data}"; then
      cpu_vendor='amd'
    elif grep -Eq 'GenuineIntel' <<< "${cpu_data}"; then
      cpu_vendor='intel'
    fi

    local settings=''
    settings="$(jq -er ".cpu_vendor = \"${cpu_vendor}\"" "${SETTINGS_FILE}")" &&
      echo "${settings}" > "${SETTINGS_FILE}" ||
      abort 'Failed to save cpu_vendor setting.'
  }

  local resolve_gpu
  resolve_gpu () {
    local gpu_data=''
    gpu_data="$(lspci 2>&1)" ||
      abort 'Unable to detect GPU data.'

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
    settings="$(jq -er ".gpu_vendor = \"${gpu_vendor}\"" "${SETTINGS_FILE}")" &&
      echo "${settings}" > "${SETTINGS_FILE}" ||
      abort 'Failed to save gpu_vendor setting.'
  }

  is_uefi &&
    is_virtual_machine &&
    resolve_cpu &&
    resolve_gpu
}

# Asks the user the installation settings in order
# to collect all the required props to install the
# new system.
ask_user () {
  local select_disk
  select_disk () {
    local fields='name,path,type,size,rm,ro,tran,hotplug,state,'
    fields+='vendor,model,rev,serial,mountpoint,mountpoints,'
    fields+='label,uuid,fstype,fsver,fsavail,fsused,fsuse%'

    local query='[.blockdevices[]|select(.type == "disk")]'

    local disks=''
    disks="$(lsblk -J -o "${fields}" | jq -cer "${query}" 2> /dev/null)"

    if has_failed; then
      abort 'Unable to list disk block devices.'
    fi

    local trim='.|gsub("^\\s+|\\s+$";"")'
    local vendor="\(.vendor|if . then .|${trim} else empty end)"
    local model="\(.model|if . then .|${trim} else empty end)"

    local value=''
    value+="[\"${vendor}\", \"${model}\", .size]|join(\" \")"
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

    local prompt=''
    prompt+="All data in ${disk} disk will be lost!"
    prompt+='\nDo you want to proceed with this disk?'

    confirm "${prompt}" || abort
    is_not_given "${REPLY}" && abort 'User input is required.'

    if is_no "${REPLY}"; then
      abort 'Sure, better be safe than sorry!'
    fi

    local settings=''
    settings="$(jq -er ".disk = \"${disk}\"" "${SETTINGS_FILE}")" &&
      echo "${settings}" > "${SETTINGS_FILE}" ||
      abort 'Failed to save disk setting.'

    local discards=''
    discards="$(lsblk -dn --discard -o DISC-GRAN,DISC-MAX "${disk}" 2>&1)" ||
      abort 'Unable to list disk block devices.'

    local trim_disk='no'

    if match "${discards}" ' *[1-9]+[TGMB] *[1-9]+[TGMB] *'; then
      trim_disk='yes'
    fi

    local settings=''
    settings="$(jq -er ".trim_disk = \"${trim_disk}\"" "${SETTINGS_FILE}")" &&
      echo "${settings}" > "${SETTINGS_FILE}" ||
      abort 'Failed to save trim_disk setting.'
  }

  local opt_in_swap_space
  opt_in_swap_space () {
    confirm 'Do you want to enable swap space?' || abort
    is_not_given "${REPLY}" && abort 'User input is required.'

    if is_no "${REPLY}"; then
      local settings=''
      settings="$(jq -er '.swap_on = "no" | del(.swap_size, .swap_type)' "${SETTINGS_FILE}")" &&
        echo "${settings}" > "${SETTINGS_FILE}" ||
        abort 'Failed to save swap_on setting.'
      
      return 0
    fi

    local settings=''
    settings="$(jq -er '.swap_on = "yes"' "${SETTINGS_FILE}")" &&
      echo "${settings}" > "${SETTINGS_FILE}" ||
      abort 'Failed to save swap_on setting.'

    ask 'Enter the size of the swap space in GBs:' || abort
    is_not_given "${REPLY}" && abort 'User input is required.'

    while is_not_integer "${REPLY}" '[1,]'; do
      ask 'Please enter a valid swap space size in GBs:' || abort
      is_not_given "${REPLY}" && abort 'User input is required.'
    done

    local swap_size="${REPLY}"

    local settings=''
    settings="$(jq -er ".swap_size = ${swap_size}" "${SETTINGS_FILE}")" &&
      echo "${settings}" > "${SETTINGS_FILE}" ||
      abort 'Failed to save swap_size setting.'

    local swap_types=''
    swap_types+='{"key": "file", "value":"File"},'
    swap_types+='{"key": "partition", "value":"Partition"}'
    swap_types="[${swap_types}]"

    pick_one 'Which type of swap to setup:' "${swap_types}" 'horizontal' || abort
    is_not_given "${REPLY}" && abort 'User input is required.'

    local swap_type="${REPLY}"
    
    local settings=''
    settings="$(jq -er ".swap_type = \"${swap_type}\"" "${SETTINGS_FILE}")" &&
      echo "${settings}" > "${SETTINGS_FILE}" ||
      abort 'Failed to save swap_type setting.'
  }

  local select_mirrors
  select_mirrors () {
    local mirrors=''
    mirrors="$(reflector --list-countries 2> /dev/null | tail -n +3 | awk '{
      match($0, /(.*)([A-Z]{2})\s+([0-9]+)/, a)
      gsub(/[ \t]+$/, "", a[1])

      frm="{\"key\": \"%s\", \"value\": \"%s\"},"
      printf frm, a[2], a[1]" ["a[3]"]"
    }')"
    
    if has_failed; then
      abort 'Unable to fetch package databases mirrors.'
    fi

    # Remove the extra comma from the last element
    mirrors="[${mirrors:+${mirrors::-1}}]"

    pick_many 'Select package databases mirrors:' "${mirrors}" 'vertical' || abort
    is_not_given "${REPLY}" && abort 'User input is required.'

    mirrors="${REPLY}"

    local settings=''
    settings="$(jq -er ".mirrors = ${mirrors}" "${SETTINGS_FILE}")" &&
      echo "${settings}" > "${SETTINGS_FILE}" ||
      abort 'Failed to save mirrors setting.'
  }

  local select_timezone
  select_timezone () {
    local timezones=''
    timezones="$(timedatectl list-timezones 2> /dev/null | awk '{
      print "{\"key\":\""$0"\",\"value\":\""$0"\"},"
    }')"
    
    if has_failed; then
      abort 'Unable to list timezones.'
    fi

    # Remove the extra comma after the last array element
    timezones="[${timezones:+${timezones::-1}}]"

    pick_one 'Select the system timezone:' "${timezones}" 'vertical' || abort
    is_not_given "${REPLY}" && abort 'User input is required.'

    local timezone="${REPLY}"

    local settings=''
    settings="$(jq -er ".timezone = \"${timezone}\"" "${SETTINGS_FILE}")" &&
      echo "${settings}" > "${SETTINGS_FILE}" ||
      abort 'Failed to save timezone setting.'
  }

  local select_locales
  select_locales () {
    local locales=''
    locales="$(cat /etc/locale.gen | tail -n +24 | grep -E '^\s*#.*' | tr -d '#' | trim | awk '{
      print "{\"key\":\""$0"\",\"value\":\""$0"\"},"
    }')"
    
    if has_failed; then
      abort 'Unable to list the locales.'
    fi
    
    # Removes the last comma delimiter from the last element
    locales="[${locales:+${locales::-1}}]"

    pick_many 'Select system locales by order:' "${locales}" 'vertical' || abort
    is_not_given "${REPLY}" && abort 'User input is required.'

    locales="${REPLY}"

    local settings=''
    settings="$(jq -er ".locales = ${locales}" "${SETTINGS_FILE}")" &&
      echo "${settings}" > "${SETTINGS_FILE}" ||
      abort 'Failed to save locales setting.'
  }

  local select_keyboard_model
  select_keyboard_model () {
    local models=''
    models="$(localectl --no-pager list-x11-keymap-models 2> /dev/null | awk '{
      print "{\"key\":\""$1"\",\"value\":\""$1"\"},"
    }')"
    
    if has_failed; then
      abort 'Unable to list keyboard models.'
    fi

    # Remove the extra comma delimiter from the last element
    models="[${models:+${models::-1}}]"

    pick_one 'Select a keyboard model:' "${models}" 'vertical' || abort
    is_not_given "${REPLY}" && abort 'User input is required.'

    local keyboard_model="${REPLY}"

    local settings=''
    settings="$(jq -er ".keyboard_model = \"${keyboard_model}\"" "${SETTINGS_FILE}")" &&
      echo "${settings}" > "${SETTINGS_FILE}" ||
      abort 'Failed to save keyboard_model setting.'
  }

  local select_keyboard_map
  select_keyboard_map () {
    local maps=''
    maps="$(localectl --no-pager list-keymaps 2> /dev/null | awk '{
      print "{\"key\":\""$0"\",\"value\":\""$0"\"},"
    }')"
    
    if has_failed; then
      abort 'Unable to list keyboard maps.'
    fi
    
    # Remove extra comma delimiter from the last element
    maps="[${maps:+${maps::-1}}]"

    pick_one 'Select a keyboard map:' "${maps}" 'vertical' || abort
    is_not_given "${REPLY}" && abort 'User input is required.'

    local keyboard_map="${REPLY}"

    local settings=''
    settings="$(jq -er ".keyboard_map = \"${keyboard_map}\"" "${SETTINGS_FILE}")" &&
      echo "${settings}" > "${SETTINGS_FILE}" ||
      abort 'Failed to save keyboard_map setting.'
  }

  local select_keyboard_layout
  select_keyboard_layout () {
    local layouts=''
    layouts="$(localectl --no-pager list-x11-keymap-layouts 2> /dev/null | awk '{
      print "{\"key\":\""$0"\",\"value\":\""$0"\"},"
    }')"
    
    if has_failed; then
      abort 'Unable to list keyboard layouts.'
    fi
    
    # Remove the extra comma delimiter from last element
    layouts="[${layouts:+${layouts::-1}}]"

    pick_one 'Select a keyboard layout:' "${layouts}" 'vertical' || abort
    is_not_given "${REPLY}" && abort 'User input is required.'

    local keyboard_layout="${REPLY}"

    local settings=''
    settings="$(jq -er ".keyboard_layout = \"${keyboard_layout}\"" "${SETTINGS_FILE}")" &&
      echo "${settings}" > "${SETTINGS_FILE}" ||
      abort 'Failed to save keyboard_layout setting.'

    local variants='{"key": "default", "value": "default"},'
    variants+="$(localectl --no-pager list-x11-keymap-variants "${keyboard_layout}" 2> /dev/null  | awk '{
      print "{\"key\":\""$0"\",\"value\":\""$0"\"},"
    }')"
    
    if has_failed; then
      abort 'Unable to list layout variants.'
    fi
    
    # Remove the extra comma delimiter from last element
    variants="[${variants:+${variants::-1}}]"

    pick_one "Select a ${keyboard_layout} layout variant:" "${variants}" vertical || abort
    is_not_given "${REPLY}" && abort 'User input is required.'

    local layout_variant="${REPLY}"

    local settings=''
    settings="$(jq -er ".layout_variant = \"${layout_variant}\"" "${SETTINGS_FILE}")" &&
      echo "${settings}" > "${SETTINGS_FILE}" ||
      abort 'Failed to save layout_variant setting.'
  }

  local select_keyboard_options
  select_keyboard_options () {
    local options=''
    options="$(localectl --no-pager list-x11-keymap-options 2> /dev/null | awk '{
      print "{\"key\":\""$0"\",\"value\":\""$0"\"},"
    }')"
    
    if has_failed; then
      abort 'Unable to list keyboard options.'
    fi

    # Remove extra comma delimiter from last element
    options="[${options:+${options::-1}}]"

    pick_one 'Select the keyboard options value:' "${options}" 'vertical' || abort
    is_not_given "${REPLY}" && abort 'User input is required.'

    local keyboard_options="${REPLY}"

    local settings=''
    settings="$(jq -er ".keyboard_options = \"${keyboard_options}\"" "${SETTINGS_FILE}")" &&
      echo "${settings}" > "${SETTINGS_FILE}" ||
      abort 'Failed to save keyboard_options setting.'
  }

  local enter_host_name
  enter_host_name () {
    ask 'Enter the name of the host:' || abort
    is_not_given "${REPLY}" && abort 'User input is required.'

    while not_match "${REPLY}" '^[a-z][a-z0-9_-]+$'; do
      ask 'Please enter a valid host name:' || abort
      is_not_given "${REPLY}" && abort 'User input is required.'
    done

    local host_name="${REPLY}"

    local settings=''
    settings="$(jq -er ".host_name = \"${host_name}\"" "${SETTINGS_FILE}")" &&
      echo "${settings}" > "${SETTINGS_FILE}" ||
      abort 'Failed to save host_name setting.'
  }

  local enter_user_name
  enter_user_name () {
    ask 'Enter the name of the user:' || abort
    is_not_given "${REPLY}" && abort 'User input is required.'

    while not_match "${REPLY}" '^[a-z][a-z0-9_-]+$'; do
      ask 'Please enter a valid user name:' || abort
      is_not_given "${REPLY}" && abort 'User input is required.'
    done

    local user_name="${REPLY}"

    local settings=''
    settings="$(jq -er ".user_name = \"${user_name}\"" "${SETTINGS_FILE}")" &&
      echo "${settings}" > "${SETTINGS_FILE}" ||
      abort 'Failed to save user_name setting.'
  }

  local enter_user_password
  enter_user_password () {
    ask_secret 'Enter the user password (at least 4 chars):' || abort
    is_not_given "${REPLY}" && abort 'User input is required.'

    while not_match "${REPLY}" '^[a-zA-Z0-9`~!@#\$%^&*()=+{};:",.<>/\?_-]{4,}$'; do
      ask_secret 'Please enter a valid password:' || abort
      is_not_given "${REPLY}" && abort 'User input is required.'
    done

    local password="${REPLY}"

    ask_secret 'Re-type the given password:' || abort
    is_not_given "${REPLY}" && abort 'User input is required.'

    while not_equals "${REPLY}" "${password}"; do
      ask_secret 'Not matched, please re-type the given password:' || abort
      is_not_given "${REPLY}" && abort 'User input is required.'
    done

    local settings=''
    settings="$(jq -er ".user_password = \"${password}\"" "${SETTINGS_FILE}")" &&
      echo "${settings}" > "${SETTINGS_FILE}" ||
      abort 'Failed to save user_password setting.'
  }

  local enter_root_password
  enter_root_password () {
    ask_secret 'Enter the root password (at least 4 chars):' || abort
    is_not_given "${REPLY}" && abort 'User input is required.'

    while not_match "${REPLY}" '^[a-zA-Z0-9`~!@#\$%^&*()=+{};:",.<>/\?_-]{4,}$'; do
      ask_secret 'Please enter a valid password:' || abort
      is_not_given "${REPLY}" && abort 'User input is required.'
    done

    local password="${REPLY}"

    ask_secret 'Re-type the given password:' || abort
    is_not_given "${REPLY}" && abort 'User input is required.'

    while not_equals "${REPLY}" "${password}"; do
      ask_secret 'Not matched, please re-type the given password:' || abort
      is_not_given "${REPLY}" && abort 'User input is required.'
    done

    local settings=''
    settings="$(jq -er ".root_password = \"${password}\"" "${SETTINGS_FILE}")" &&
      echo "${settings}" > "${SETTINGS_FILE}" ||
      abort 'Failed to save root_password setting.'
  }

  local select_kernel
  select_kernel () {
    local kernels=''
    kernels+='{"key": "stable", "value": "Stable"},'
    kernels+='{"key": "lts", "value": "LTS"}'
    kernels="[${kernels}]"

    pick_one 'Select which linux kernel to install:' "${kernels}" 'horizontal' || abort
    is_not_given "${REPLY}" && abort 'User input is required.'

    local kernel="${REPLY}"

    local settings=''
    settings="$(jq -er ".kernel = \"${kernel}\"" "${SETTINGS_FILE}")" &&
      echo "${settings}" > "${SETTINGS_FILE}" ||
      abort 'Failed to save kernel setting.'
  }

  while true; do
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
    
    log 'Review your installation settings:'
    jq 'del(.user_password, .root_password)' "${SETTINGS_FILE}" ||
      abort -n 'Unable to read installation settings.'

    confirm -n 'Do you want to ask for settings again?' || abort
    is_not_given "${REPLY}" && abort 'User input is required.'

    if is_no "${REPLY}"; then
      break
    fi

    clear
  done

  local disk=''
  disk="$(jq -cer '.disk' "${SETTINGS_FILE}")" ||
    abort 'Unable to read disk setting.'

  local prompt=''
  prompt+="All data in ${disk} disk will be lost!"
  prompt+='\nDo you really want to proceed?'

  confirm "${prompt}" || abort
  is_not_given "${REPLY}" && abort 'User input is required.'

  if is_no "${REPLY}"; then
    abort 'Sure, maybe next time!'
  fi

  local branch=''
  branch="$(git branch --show-current)" ||
    abort ERROR 'Failed to read the current branch.'

  if equals "${branch}" "master"; then
    log "Installing Stack Linux:"
  else
    log "Installing Stack Linux branch ${branch}:"
  fi

  sleep 2
}

# Runs the disk partitioning tasks.
run_diskpart () {
  log 'Partitioning the system disk...'

  bash src/installer/diskpart.sh 2>&1 >> "${LOG_FILE}"

  if has_failed; then
    abort -n 'Oops, a fatal error has been occurred.'
  fi

  log 'System disk partitions are ready.'
}

# Runs the bootstrap installation tasks.
run_bootstrap () {
  log 'Installing the linux kernel...'

  bash src/installer/bootstrap.sh 2>&1 >> "${LOG_FILE}"

  if has_failed; then
    abort -n 'Oops, a fatal error has been occurred.'
  fi

  log 'Linux kernel has been installed.'
}

# Executes the base system installation and setup tasks.
install_system () {
  log 'Setting up the base system and packages...'

  local cmd='cd /stack && ./src/installer/system.sh'

  arch-chroot /mnt runuser -u root -- bash -c "${cmd}" 2>&1 >> "${LOG_FILE}"
  
  if has_failed; then
    abort -n 'Oops, a fatal error has been occurred.'
  fi

  log 'System setup has been completed.'
}

# Executes the applications installation tasks.
install_apps () {
  log 'Installing the extra applications...'

  local user_name=''
  user_name="$(jq -cer '.user_name' "${SETTINGS_FILE}")"

  if has_failed; then
    abort -n 'Unable to read user_name setting.'
  fi

  local cmd='cd /stack && ./src/installer/apps.sh'

  arch-chroot /mnt runuser -u "${user_name}" -- bash -c "${cmd}" 2>&1 >> "${LOG_FILE}"
  
  if has_failed; then
    abort -n 'Oops, a fatal error has been occurred.'
  fi

  log 'Applications have been installed.'
}

# Grants temporary sudo permissions.
grant_perms () {
  local rule='%wheel ALL=(ALL:ALL) NOPASSWD: ALL'

  sed -i "s/^# \(${rule}\)/\1/" /mnt/etc/sudoers

  if has_failed || ! grep -q "^${rule}" /mnt/etc/sudoers; then
    abort -n 'Failed to grant permissions.'
  fi
}

# Revokes temporarily granted sudo permissions.
revoke_perms () {
  local rule='%wheel ALL=(ALL:ALL) NOPASSWD: ALL'

  sed -i "s/^\(${rule}\)/# \1/" /mnt/etc/sudoers

  if has_failed || ! grep -q "^# ${rule}" /mnt/etc/sudoers; then
    log -n 'Failed to revoke permissions.'
  fi
}

# Clean installation files and collect logs.
clean () {
  # Remove installation files
  rm -rf /mnt/stack ||
    log 'Unable to remove installation files.'

  # Copy the installation log files to the new system
  mkdir -p "/mnt/${LOGS_HOME}" &&
    cp ${LOG_FILE} "/mnt/${LOGS_HOME}" ||
    log 'Unable to copy log file to the new system.'

  # Clean redundant log file from live media
  rm -f "${LOG_FILE}" ||
    log 'Unable to remove log file from live media.'
}

# Restarts the system.
restart () {
  log -n 'Installation process has been completed.'
  log 'Rebooting the system in 15 secs...'

  sleep 15
  umount -R /mnt || log 'Ignoring busy mount points.'
  reboot
}

init &&
  welcome &&
  detect &&
  ask_user &&
  run_diskpart &&
  run_bootstrap &&
  grant_perms &&
  install_system &&
  install_apps &&
  revoke_perms &&
  clean &&
  restart
