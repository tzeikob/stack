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

  echo -e "UEFI mode is set to ${uefi_mode}"
}

# Resolves if the the system is a virtual machine.
is_virtual_machine () {
  local vm_vendor="$(systemd-detect-virt)"

  if is_not_empty "${vm_vendor}" && not_equals "${vm_vendor}" 'none'; then
    save_setting 'vm' 'yes'
    save_setting 'vm_vendor' "${vm_vendor}"

    echo -e 'Virtual machine is set to yes'
    echo -e "Virtual machine vendor is set to ${vm_vendor}"
  else
    save_setting 'vm' 'no'
  fi
}

# Resolves the vendor of the CPU installed CPU on the system.
resolve_cpu () {
  local cpu_data=''
  cpu_data="$(lscpu)" || fail 'Unable to read CPU data'

  local cpu_vendor='generic'

  if grep -Eq 'AuthenticAMD' <<< "${cpu_data}"; then
    cpu_vendor='amd'
  elif grep -Eq 'GenuineIntel' <<< "${cpu_data}"; then
    cpu_vendor='intel'
  fi

  save_setting 'cpu_vendor' "${cpu_vendor}"

  echo -e "CPU vendor is set to ${cpu_vendor}"
}

# Resolves the vendor of the GPU installed on the system.
resolve_gpu () {
  local gpu_data=''
  gpu_data="$(lspci)" || fail 'Unable to read GPU data'

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

  echo -e "GPU vendor is set to ${gpu_vendor}"
}

# Resolves if the installation disk supports TRIM.
is_disk_trimmable () {
  local disk=''
  disk="$(get_setting 'disk')"

  local discards=''
  discards="$(
    lsblk -dn --discard -o DISC-GRAN,DISC-MAX "${disk}"
  )" || fail 'Unable to list disk block devices'

  local trim_disk='no'

  if match "${discards}" ' *[1-9]+[TGMB] *[1-9]+[TGMB] *'; then
    trim_disk='yes'
  fi

  save_setting 'trim_disk' "${trim_disk}"

  echo -e "Disk trim mode is set to ${trim_disk}"
}

# Resolves the synaptics touch pad.
resolve_synaptics () {
  local query='.*SynPS/2.*Synaptics.*TouchPad.*'

  if grep -Rq "${query}" /proc/bus/input/devices; then
    save_setting 'synaptics' 'yes'

    echo -e "Synaptics touch pad set to yes"
  else
    save_setting 'synaptics' 'no'
  fi
}

echo -e "Resolving system hardware data..."

is_uefi &&
  is_virtual_machine &&
  resolve_cpu &&
  resolve_gpu &&
  is_disk_trimmable &&
  resolve_synaptics

sleep 3
