#!/bin/bash

set -Eeo pipefail

source src/commons/process.sh
source src/commons/error.sh
source src/commons/logger.sh
source src/commons/validators.sh

SETTINGS=./settings.json

# Resolves if UEFI mode is supported by the system.
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

# Resolves if the the system is a virtual machine.
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

  local settings=''
  settings="$(jq -er ".cpu_vendor = \"${cpu_vendor}\"" "${SETTINGS}")" &&
    echo "${settings}" > "${SETTINGS}" ||
    abort ERROR 'Failed to save cpu_vendor setting.'

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

  local settings=''
  settings="$(jq -er ".gpu_vendor = \"${gpu_vendor}\"" "${SETTINGS}")" &&
    echo "${settings}" > "${SETTINGS}" ||
    abort ERROR 'Failed to save gpu_vendor setting.'

  log INFO "GPU vendor is set to ${gpu_vendor}."
}

# Resolves if the installation disk supports TRIM.
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

log INFO 'Script detection.sh started.'
log INFO 'Resolving system hardware data...'

is_uefi &&
  is_virtual_machine &&
  resolve_cpu &&
  resolve_gpu &&
  is_disk_trimmable

log INFO 'Script detection.sh has finished.'

resolve detection 15 && sleep 2
