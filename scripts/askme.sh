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

  echo "UEFI mode is set to ${uefi_mode}"
}

# Resolves the vendor of the CPU installed CPU on the system.
resolve_cpu () {
  echo 'Start detecting CPU vendor...'

  local cpu_data=''
  cpu_data="$(lscpu)"
  
  if has_failed; then
    echo 'Unable to resolve CPU data'
    exit 1
  fi

  local cpu_vendor='generic'

  if grep -Eq 'AuthenticAMD' <<< "${cpu_data}"; then
    cpu_vendor='amd'
  elif grep -Eq 'GenuineIntel' <<< "${cpu_data}"; then
    cpu_vendor='intel'
  fi

  save_setting 'cpu_vendor' "${cpu_vendor}"

  echo "CPU vendor is set to ${cpu_vendor}"
}

# Resolves the vendor of the GPU installed on the system.
resolve_gpu () {
  echo 'Start detecting GPU vendor...'

  local gpu_data=''
  gpu_data="$(lspci)"
  
  if has_failed; then
    echo 'Unable to resolve GPU data'
    exit 1
  fi

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

  echo "GPU vendor is set to ${gpu_vendor}"
}

# Asks the user to install or not the synaptics touch drivers.
opt_in_synaptics () {
  confirm 'Do you want to install synaptics drivers?' || exit 1
  is_not_given "${REPLY}" && echo 'Installation process canceled' && exit 1

  local synaptics='no'

  if is_yes "${REPLY}"; then
    synaptics='yes'
  fi

  save_setting 'synaptics' "${synaptics}"

  echo "Synaptics drivers are set to ${synaptics}"
}

# Resolves information and option of the system's hardware.
resolve_hardware () {
  echo 'Started resolving system hardware...'

  is_uefi || exit 1

  local vm_vendor=''
  vm_vendor="$(systemd-detect-virt)"

  if not_equals "${vm_vendor}" 'none'; then
    save_setting 'vm' 'yes'
    save_setting 'vm_vendor' "${vm_vendor}"

    echo 'Virtual machine is set to yes'
    echo "Virtual machine vendor is set to ${vm_vendor}"
  else
    save_setting 'vm' 'no'

    resolve_cpu && resolve_gpu && opt_in_synaptics || exit 1
  fi

  echo -e 'Hardware has been resolved successfully\n'
}

# Asks the user to select the installation disk.
select_disk () {
  local fields='name,path,type,size,rm,ro,tran,hotplug,state,'
  fields+='vendor,model,rev,serial,mountpoint,mountpoints,'
  fields+='label,uuid,fstype,fsver,fsavail,fsused,fsuse%'

  local query='[.blockdevices[]|select(.type == "disk")]'

  local disks=''
  disks="$(lsblk -J -o "${fields}" | jq -cer "${query}")" || exit 1

  local trim='.|gsub("^\\s+|\\s+$";"")'
  local vendor="\(.vendor|if . then .|${trim} else empty end)"

  local value=''
  value+="[\"${vendor}\", .rev, .serial, .size]|join(\" \")"
  value="\(${value}|if . != \"\" then \" [\(.|${trim})]\" else empty end)"
  value="\(.path)${value}"

  local query=''
  query="[.[]|{key: .path, value: \"${value}\"}]"

  disks="$(echo "${disks}" | jq -cer "${query}")" || exit 1

  pick_one 'Select the installation disk:' "${disks}" 'vertical' || exit 1
  is_not_given "${REPLY}" && echo 'Installation process canceled' && exit 1

  local disk="${REPLY}"

  echo -e "\nCAUTION, all data in \"${disk}\" will be lost!"
  confirm 'Do you want to proceed with this disk?'

  if is_not_given "${REPLY}" || is_no "${REPLY}"; then
    echo 'Installation process canceled'
    exit 1
  fi

  save_setting 'disk' "${disk}"

  confirm 'Is this disk an SSD drive?' || exit 1
  is_not_given "${REPLY}" && echo 'Installation process canceled' && exit 1

  if is_yes "${REPLY}"; then
    save_setting 'is_ssd' 'yes'
  else
    save_setting 'is_ssd' 'no'
  fi

  local discards=''
  discards=($(lsblk -dn --discard -o DISC-GRAN,DISC-MAX "${disk}")) || exit 1

  if match "${discards[1]}" '[1-9]+[TGMB]' && match "${discards[2]}" '[1-9]+[TGMB]'; then
    confirm 'Do you want to enable trim on this disk?' || exit 1
    is_not_given "${REPLY}" && echo 'Installation process canceled' && exit 1

    if is_yes "${REPLY}"; then
      save_setting 'trim_disk' 'yes'
    else
      save_setting 'trim_disk' 'no'
    fi
  else
    save_setting 'trim_disk' 'no'
  fi

  echo -e "Installation disk is set to block device ${disk}\n"
}

# Asks the user to enable or not the swap space.
opt_in_swap_space () {
  confirm 'Do you want to enable swap space?' || exit 1
  is_not_given "${REPLY}" && echo 'Installation process canceled' && exit 1

  if is_no "${REPLY}"; then
    save_setting 'swap_on' 'no'
    echo 'Swap is set to off'

    return 0
  fi

  save_setting 'swap_on' 'yes'

  ask 'Enter the size of the swap space in GBs:' || exit 1

  while is_not_integer "${REPLY}" '[1,]'; do
    echo ' Swap space size should be a positive integer'
    ask ' Please enter a valid swap space size in GBs:' || exit 1
  done

  local swap_size="${REPLY}"

  save_setting 'swap_size' "${swap_size}"

  local swap_types=''
  swap_types+='{"key": "file", "value":"File"},'
  swap_types+='{"key": "partition", "value":"Partition"}'
  swap_types="[${swap_types}]"

  pick_one 'Which type of swap to setup:' "${swap_types}" 'horizontal' || exit 1
  is_not_given "${REPLY}" && echo 'Installation process canceled' && exit 1

  local swap_type="${REPLY}"

  save_setting 'swap_type' "${swap_type}"

  echo "Swap type is set to ${swap_type}"
  echo -e "Swap size is set to ${swap_size}GB\n"
}

# Asks the user to select the mirror countries used for installation and updates.
select_mirrors () {
  local mirrors=''
  mirrors="$(reflector --list-countries | tail -n +3 | awk '{
    match($0, /(.*)([A-Z]{2})\s+([0-9]+)/, a)
    gsub(/[ \t]+$/, "", a[1])

    frm="{\"key\": \"%s\", \"value\": \"%s\"},"
    printf frm, a[2], a[1]" ["a[3]"]"
  }' 2> /dev/null)"

  if has_failed; then
    echo 'Unable to fetch mirror countries'
    exit 1
  fi

  # Remove the extra comma from the last element
  mirrors="[${mirrors:+${mirrors::-1}}]"

  pick_many 'Select mirror countries:' "${mirrors}" 'vertical' || exit 1
  is_not_given "${REPLY}" && echo 'Installation process canceled' && exit 1

  mirrors="${REPLY}"

  save_setting 'mirrors' "${mirrors}"

  echo -e "Mirror countries are set to ${mirrors}\n"
}

# Asks the user to select the system's timezone.
select_timezone () {
  local timezones=''
  timezones="$(timedatectl list-timezones | awk '{
    print "{\"key\":\""$0"\",\"value\":\""$0"\"},"
  }')"

  if has_failed; then
    echo 'Unable to fetch the available timezones'
    exit 1
  fi

  # Remove the extra comma after the last array element
  timezones="[${timezones:+${timezones::-1}}]"

  pick_one 'Select the system timezone:' "${timezones}" 'vertical' || exit 1
  is_not_given "${REPLY}" && echo 'Installation process canceled' && exit 1

  local timezone="${REPLY}"

  save_setting 'timezone' "${timezone}"

  echo -e "Timezone is set to ${timezone}\n"
}

# Asks the user to select which locales to install.
select_locales () {
  local locales=''
  locales="$(cat /etc/locale.gen | tail -n +24 | grep -E '^\s*#.*' | tr -d '#' | trim | awk '{
    print "{\"key\":\""$0"\",\"value\":\""$0"\"},"
  }')"

  if has_failed; then
    echo 'Unable to fetch the available locales'
    exit 1
  fi
  
  # Removes the last comma delimiter from the last element
  locales="[${locales:+${locales::-1}}]"

  pick_many 'Select system locales by order:' "${locales}" 'vertical' || exit 1
  is_not_given "${REPLY}" && echo 'Installation process canceled' && exit 1

  locales="${REPLY}"

  save_setting 'locales' "${locales}"

  echo -e "Locales are set to ${locales}\n"
}

# Asks the user to select the keyboard model.
select_keyboard_model () {
  # TODO: localectl needs xorg deps to provide x11 kb models
  save_setting 'keyboard_model' 'pc105'
  return 0

  local models=''
  models="$(localectl --no-pager list-x11-keymap-models | awk '{
    print "{\"key\":\""$1"\",\"value\":\""$1"\"},"
  }')"

  if has_failed; then
    echo 'Unable to fetch the available keyboard models'
    exit 1
  fi

  # Remove the extra comma delimiter from the last element
  models="[${models:+${models::-1}}]"

  pick_one 'Select a keyboard model:' "${models}" 'vertical' || exit 1
  is_not_given "${REPLY}" && echo 'Installation process canceled' && exit 1

  local keyboard_model="${REPLY}"

  save_setting 'keyboard_model' "${keyboard_model}"

  echo -e "Keyboard model is set to ${keyboard_model}\n"
}

# Asks the user to select the keyboard map.
select_keyboard_map () {
  local maps=''
  maps="$(localectl --no-pager list-keymaps | awk '{
    print "{\"key\":\""$0"\",\"value\":\""$0"\"},"
  }')"

  if has_failed; then
    echo 'Unable to fetch the available keyboard maps'
    exit 1
  fi
  
  # Remove extra comma delimiter from the last element
  maps="[${maps:+${maps::-1}}]"

  pick_one 'Select a keyboard map:' "${maps}" 'vertical' || exit 1
  is_not_given "${REPLY}" && echo 'Installation process canceled' && exit 1

  local keyboard_map="${REPLY}"

  save_setting 'keyboard_map' "${keyboard_map}"

  echo -e "Keyboard map is set to ${keyboard_map}\n"
}

# Asks the user to select keyboard layouts.
select_keyboard_layouts () {
  # TODO: localectl needs xorg deps to provide x11 kb layouts
  save_setting 'keyboard_layouts' '["us", "gr", "de"]'
  return 0

  local layouts=''
  layouts="$(localectl --no-pager list-x11-keymap-layouts | awk '{
    print "{\"key\":\""$0"\",\"value\":\""$0"\"},"
  }')"

  if has_failed; then
    echo 'Unable to fetch the available keyboard layouts'
    exit 1
  fi
  
  # Remove the extra comma delimiter from last element
  layouts="[${layouts:+${layouts::-1}}]"

  pick_many 'Select keyboard layouts:' "${layouts}" 'vertical' || exit 1
  is_not_given "${REPLY}" && echo 'Installation process canceled' && exit 1

  keyboard_layouts="${REPLY}"

  save_setting 'keyboard_layouts' "${keyboard_layouts}"

  echo -e "Keyboard layouts are set to ${keyboard_layouts}\n"
}

# Asks the user to select keyboard switch options.
select_keyboard_options () {
  # TODO: localectl needs xorg deps to provide x11 kb options
  save_setting 'keyboard_options' 'grp:alt_shift_toggle'
  return 0

  local options=''
  options="$(localectl --no-pager list-x11-keymap-options | awk '{
    print "{\"key\":\""$0"\",\"value\":\""$0"\"},"
  }')"

  if has_failed; then
    echo 'Unable to fetch the available keyboard options'
    exit 1
  fi

  # Remove extra comma delimiter from last element
  options="[${options:+${options::-1}}]"

  pick_one 'Select the keyboard options value:' "${options}" 'vertical' || exit 1
  is_not_given "${REPLY}" && echo 'Installation process canceled' && exit 1

  keyboard_options="${REPLY}"

  save_setting 'keyboard_options' "${keyboard_options}"

  echo -e "Keyboard layouts are set to ${keyboard_options}\n"
}

# Asks the user to set the name of the host.
enter_host_name () {
  ask 'Enter the name of the host:' || exit 1

  while not_match "${REPLY}" '^[a-z][a-z0-9_-]+$'; do
    echo ' Host name should start with a latin char'
    ask ' Please enter a valid host name:' || exit 1
  done

  local host_name="${REPLY}"

  save_setting 'host_name' "${host_name}"

  echo -e "Hostname is set to ${host_name}\n"
}

# Asks the user to set the name of the sudoer user.
enter_user_name () {
  ask 'Enter the name of the user:' || exit 1

  while not_match "${REPLY}" '^[a-z][a-z0-9_-]+$'; do
    echo ' Host name should start with a latin char'
    ask ' Please enter a valid user name:' || exit 1
  done

  local user_name="${REPLY}"

  save_setting 'user_name' "${user_name}"

  echo -e "User name is set to ${user_name}\n"
}

# Asks the user to set the password of the sudoer user.
enter_user_password () {
  ask_secret 'Enter the user password:' || exit 1

  while not_match "${REPLY}" '^[a-zA-Z0-9@&!#%\$_-]{4,}$'; do
    echo ' Password must be at least 4 chars of a-z A-Z 0-9 @&!#%\$_-'
    ask_secret ' Please enter a stronger user password:' || exit 1
  done

  local password="${REPLY}"

  ask_secret 'Re-type the given password:' || exit 1

  while not_equals "${REPLY}" "${password}"; do
    ask_secret ' Not matched, please re-type the given password:' || exit 1
  done

  save_setting 'user_password' "${password}"

  echo -e 'User password is set successfully\n'
}

# Asks the user to set the password of the root user.
enter_root_password () {
  ask_secret 'Enter the root password:' || exit 1

  while not_match "${REPLY}" '^[a-zA-Z0-9@&!#%\$_-]{4,}$'; do
    echo ' Password must be at least 4 chars of a-z A-Z 0-9 @&!#%\$_-'
    ask_secret ' Please enter a stronger root password:' || exit 1
  done

  local password="${REPLY}"

  ask_secret 'Re-type the given password:' || exit 1

  while not_equals "${REPLY}" "${password}"; do
    ask_secret ' Not matched, please re-type the given password:' || exit 1
  done

  save_setting 'root_password' "${password}"

  echo -e 'Root password is set successfully\n'
}

# Asks the user which linux kernels to install.
select_kernels () {
  local kernels=''
  kernels+='{"key": "stable", "value": "Stable"},'
  kernels+='{"key": "lts", "value": "LTS"}'
  kernels="[${kernels}]"

  pick_many 'Select which linux kernels to install:' "${kernels}" 'horizontal' || exit 1
  is_not_given "${REPLY}" && echo 'Installation process canceled' && exit 1

  kernels="${REPLY}"

  save_setting 'kernels' "${kernels}"

  echo -e "Linux kernels are set to ${kernels}\n"
}

echo -e '\nStarting to collect the installation settings...'

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
    select_kernels

  echo -e '\nInstallation settings have been set to:'

  print_settings 'secure'

  confirm 'Do you agree to go with these settings?' || exit 1
  is_not_given "${REPLY}" && echo 'Installation process canceled' && exit 1

  if is_yes "${REPLY}"; then
    break
  fi

  clear
  echo 'Starting another run to collect new installation settings...'
done

echo -e '\nCAUTION, THIS IS THE LAST WARNING!'
echo 'ALL data in the disk will be LOST FOREVER!'

confirm 'Do you want to proceed?' || exit 1

if is_not_given "${REPLY}" || is_no "${REPLY}"; then
  echo 'Installation process canceled'
  exit 1
fi

echo 'Moving to the partitioning process...'
sleep 5
