#!/bin/bash

set -Eeo pipefail

source /opt/stack/commons/utils.sh
source /opt/stack/commons/logger.sh
source /opt/stack/commons/validators.sh

# Resolves if UEFI mode is supported by the system.
is_uefi () {
  local uefi_mode='no'

  if directory_exists '/sys/firmware/efi/efivars'; then
    uefi_mode='yes'
  fi

  save_setting 'uefi_mode' "\"${uefi_mode}\""

  log INFO "UEFI mode is set to ${uefi_mode}."
}

# Resolves if the the system is a virtual machine.
is_virtual_machine () {
  local vm_vendor="$(
    systemd-detect-virt 2>&1
  )"

  if is_not_empty "${vm_vendor}" && not_equals "${vm_vendor}" 'none'; then
    save_setting 'vm' '"yes"'
    save_setting 'vm_vendor' "\"${vm_vendor}\""

    log INFO 'Virtual machine is set to yes.'
    log INFO "Virtual machine vendor is set to ${vm_vendor}."
  else
    save_setting 'vm' '"no"'
  fi
}

# Resolves the vendor of the CPU installed on the system.
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

  save_setting 'cpu_vendor' "\"${cpu_vendor}\""

  log INFO "CPU vendor is set to ${cpu_vendor}."
}

# Resolves the vendor of the GPU installed on the system.
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

  save_setting 'gpu_vendor' "\"${gpu_vendor}\""

  log INFO "GPU vendor is set to ${gpu_vendor}."
}

# Resolves if the installation disk supports TRIM.
is_disk_trimmable () {
  local disk=''
  disk="$(get_setting 'disk')" || abort ERROR 'Unable to read disk setting.'

  local discards=''
  discards="$(
    lsblk -dn --discard -o DISC-GRAN,DISC-MAX "${disk}" 2>&1
  )" || abort ERROR 'Unable to list disk block devices.'

  local trim_disk='no'

  if match "${discards}" ' *[1-9]+[TGMB] *[1-9]+[TGMB] *'; then
    trim_disk='yes'
  fi

  save_setting 'trim_disk' "\"${trim_disk}\""

  log INFO "Disk trim mode is set to ${trim_disk}."
}

# Resolves the synaptics touch pad.
resolve_synaptics () {
  local query='.*SynPS/2.*Synaptics.*TouchPad.*'

  if grep -Eq "${query}" /proc/bus/input/devices; then
    save_setting 'synaptics' '"yes"'
    
    log INFO 'Synaptics touch pad set to yes.'
  else
    save_setting 'synaptics' '"no"'
  fi
}

# Resolves the installaction script by addressing
# some extra post execution tasks.
resolve () {
  # Read the current progress as the number of log lines
  local lines=0
  lines=$(cat /var/log/stack/detection.log | wc -l) ||
    abort ERROR 'Unable to read the current log lines.'

  local total=15

  # Fill the log file with fake lines to trick tqdm bar on completion
  if [[ ${lines} -lt ${total} ]]; then
    local lines_to_append=0
    lines_to_append=$((total - lines))

    while [[ ${lines_to_append} -gt 0 ]]; do
      echo '~'
      sleep 0.15
      lines_to_append=$((lines_to_append - 1))
    done
  fi

  return 0
}

log INFO 'Script detection.sh started.'
log INFO 'Resolving system hardware data...'

is_uefi &&
  is_virtual_machine &&
  resolve_cpu &&
  resolve_gpu &&
  is_disk_trimmable &&
  resolve_synaptics

log INFO 'Script detection.sh has finished.'

resolve && sleep 2
