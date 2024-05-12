#!/bin/bash

set -o pipefail

source /opt/stack/commons/process.sh
source /opt/stack/commons/input.sh
source /opt/stack/commons/auth.sh
source /opt/stack/commons/error.sh
source /opt/stack/commons/logger.sh
source /opt/stack/commons/json.sh
source /opt/stack/commons/math.sh
source /opt/stack/commons/validators.sh
source /opt/stack/tools/disks/helpers.sh

# Shows a short status of the disks and filesystem.
# Outputs:
#  A list of disks and filesystem data.
show_status () {
  local alt_fstype='.children|'
  alt_fstype+='if . and length>0'
  alt_fstype+=' then (.[0]|.fstype|if . then  " \(.|ascii_upcase)" else "" end)'
  alt_fstype+=' else "" end'

  local alt_fsuse='.children|'
  alt_fsuse+='if . and length>0'
  alt_fsuse+=' then (.[0]|."fsuse%"|if . then  " \(.)" else "" end)'
  alt_fsuse+=' else "" end'

  local parts=''
  parts+='\(.path)'
  parts+="\(if .fstype then \" \(.fstype|ascii_upcase)\" else ${alt_fstype} end)"
  parts+="\(if .\"fsuse%\" then \" \(.\"fsuse%\")\" else ${alt_fsuse} end)"
  parts=".children|if . and length>0 then .[]|\"${parts}\" else \"\" end"
  parts="[${parts}]|join(\"\n         \")"

  local query=''
  query+='Disk:    \(.path)\n'
  query+='Vendor:  \(.vendor|if . and . != "" then gsub("^\\s+|\\s+$";"") else "n/a" end)\n'
  query+='Model:   \(.model|if . and . != "" then . else "n/a" end)\n'
  query+='Size:    \(.size)\n'
  query+="Parts:   \(if .children then ${parts} else \"none\" end)"

  query="[.[]|\"${query}\"]|join(\"\n\n\")"

  find_disks | jq -cer "${query}" || return 1

  echo

  swapon --noheadings --show | awk -F' ' '{
    printf "%-8s %s\n", "Swap:", $1
    printf "%-8s %s\n", "Type:", $2
    printf "%-8s %s\n", "Used:", $4"/"$3
  }' || return 1

  cat /proc/meminfo | grep -E 'Swap.*' | awk -F':' '{
    gsub(/^[ \t]+/,"",$1)
    gsub(/[ \t]+$/,"",$1)
    gsub(/^[ \t]+/,"",$2)
    gsub(/[ \t]+$/,"",$2)

    if ($1 == "SwapCached") $1="Cached"
    if ($1 == "SwapTotal") $1="Total"
    if ($1 == "SwapFree") $1="Free"
    printf "%-8s %s\n", $1":", $2
  }' || return 1
}

# Shows the data of the disk block device with
# the given path.
# Arguments:
#  path: the path of a disk block device
# Outputs:
#  A long text of disk block device data.
show_disk () {
  local path="${1}"

  if is_not_given "${path}"; then
    on_script_mode &&
      log 'Missing the disk path.' && return 2

    pick_disk || return $?
    is_empty "${REPLY}" && log 'Disk path is required.' && return 2
    path="${REPLY}"
  fi

  if is_not_disk "${path}"; then
    log "Path ${path} is not a disk device."
    return 2
  fi

  local disk=''
  disk="$(find_disk "${path}")" || return 1

  local alt_fstype='.children|'
  alt_fstype+='if . and length>0'
  alt_fstype+=' then (.[0]|.fstype|if . then  " \(.|ascii_upcase)" else "" end)'
  alt_fstype+=' else "" end'

  local alt_fsuse='.children|'
  alt_fsuse+='if . and length>0'
  alt_fsuse+=' then (.[0]|."fsuse%"|if . then  " \(.)" else "" end)'
  alt_fsuse+=' else "" end'

  local alt_label='.children|'
  alt_label+='if . and length>0'
  alt_label+=' then (.[0]|.label|if . then  " [\(.)]" else "" end)'
  alt_label+=' else "" end'

  local parts=''
  parts+='\(.path)'
  parts+="\(if .fstype then \" \(.fstype|ascii_upcase)\" else ${alt_fstype} end)"
  parts+="\(if .\"fsuse%\" then \" \(.\"fsuse%\")\" else ${alt_fsuse} end)"
  parts+="\(if .label then \" [\(.label)]\" else ${alt_label} end)"
  parts=".children|if . and length>0 then .[]|\"${parts}\" else \"\" end"
  parts="[${parts}]|join(\"\n            \")"

  local query=''
  query+='Name:       \(.name)\n'
  query+='Path:       \(.path)\n'
  query+='Removable:  \(.rm)\n'
  query+='ReadOnly:   \(.ro)\n'
  query+='Transfer:   \(.tran)\n'
  query+='HotPlug:    \(.hotplug)\n'
  query+='Size:       \(.size)\n'
  query+='Vendor:     \(.vendor|if . and . != "" then . else "n/a" end)\n'
  query+='Model:      \(.model|if . and . != "" then . else "n/a" end)\n'
  query+='Revision:   \(.rev|if . and . != "" then . else "n/a" end)\n'
  query+='Serial:     \(.serial|if . and . != "" then . else "n/a" end)\n'
  query+='State:      \(.state|if . and . != "" then . else "n/a" end)\n'
  query+="Parts:      \(if .children then ${parts} else \"none\" end)"

  echo "${disk}" | jq -cer "\"${query}\"" || return 1
}

# Shows the data of the partition block device.
# Arguments:
#  path: the path of a partition block device
# Outputs:
#  A long text of partition block device data.
show_partition () {
  local path="${1}"

  if is_not_given "${path}"; then
    on_script_mode &&
      log 'Missing the partition path.' && return 2

    pick_disk || return $?
    is_empty "${REPLY}" && log 'Disk path is required.' && return 2
    local disk="${REPLY}"

    pick_partition "${disk}" || return $?
    is_empty "${REPLY}" && log 'Partition path is required.' && return 2
    path="${REPLY}"
  fi
  
  if is_not_partition "${path}"; then
    log "Path ${path} is not a partition device."
    return 2
  fi

  local part=''
  part="$(find_partition "${path}")" || return 1

  local alt_fstype='.children|'
  alt_fstype+='if . and length>0'
  alt_fstype+=' then (.[0]|.fstype|if . then  "File System:  \(.|ascii_upcase)\n" else "" end)'
  alt_fstype+=' else "" end'

  local alt_fsavail='.children|'
  alt_fsavail+='if . and length>0'
  alt_fsavail+=' then (.[0]|.fsavail|if . then  "\nFree Space:   \(.)" else "" end)'
  alt_fsavail+=' else "" end'

  local alt_fsused='.children|'
  alt_fsused+='if . and length>0'
  alt_fsused+=' then (.[0]|if .fsused then  "\nUsed Space:   \(.fsused) [\(."fsuse%")]" else "" end)'
  alt_fsused+=' else "" end'

  local alt_label='.children|'
  alt_label+='if . and length>0'
  alt_label+=' then (.[0]|.label|if . then  "\nLabel:        \(.)" else "" end)'
  alt_label+=' else "" end'

  local alt_uuid='.children|'
  alt_uuid+='if . and length>0'
  alt_uuid+=' then (.[0]|.uuid|if . then  "\nUUID:         \(.)" else "" end)'
  alt_uuid+=' else "" end'

  local alt_mountpoint=''
  alt_mountpoint+='.veracrypt|if . then "\nMount:        \(.mountpoint)" else "" end'

  local query=''
  query+='Name:         \(.name) \(if .veracrypt then "[encrypted]" else "" end)\n'
  query+='Path:         \(.path)\n'
  query+="\(if .fstype then \"File System:  \(.fstype|ascii_upcase)\n\" else ${alt_fstype} end)"
  query+='Removable:    \(.rm)\n'
  query+='ReadOnly:     \(.ro)\n'
  query+='HotPlug:      \(.hotplug)\n'
  query+='Size:         \(.size)'
  query+="\(if .fsavail then \"\nFree Space:   \(.fsavail)\" else ${alt_fsavail} end)"
  query+="\(if .fsused then \"\nUsed Space:   \(.fsused) [\(.\"fsuse%\")]\" else ${alt_fsused} end)"
  query+="\(if .label then \"\nLabel:        \(.label)\" else ${alt_label} end)"
  query+="\(if .uuid then \"\nUUID:         \(.uuid)\" else ${alt_uuid} end)"
  query+='\(.veracrypt|if . then "\nSlot:         \(.slot)" else "" end)'
  query+='\(.veracrypt|if . then "\nHidden:       \(.hidden_protected)" else "" end)'
  query+='\(.veracrypt|if . then "\nEncryption:   \(.encryption_algo):\(.prf) [\(.mode)]" else "" end)'
  query+='\(.veracrypt|if . then "\nBlock:        \(.block_size)" else "" end)'
  query+='\(.veracrypt|if . then "\nMapped:       \(.device)" else "" end)'
  query+="\(if .mountpoint then \"\nMount:        \(.mountpoint)\" else ${alt_mountpoint} end)"

  echo "${part}" | jq -cer "\"${query}\"" || return 1
}

# Shows the data of the rom block device with
# the given path.
# Arguments:
#  path: the path of a rom block device
# Outputs:
#  A long text of rom block device data.
show_rom () {
  local path="${1}"

  if is_not_given "${path}"; then
    on_script_mode &&
      log 'Missing rom path.' && return 2

    pick_rom || return $?
    is_empty "${REPLY}" && log 'Rom path is required.' && return 2
    path="${REPLY}"
  fi

  if is_not_rom "${path}"; then
    log "Path ${path} is not a rom device."
    return 2
  fi

  local rom=''
  rom="$(find_rom "${path}")" || return 1

  local query=''
  query+='Name:          \(.name)\n'
  query+='Path:          \(.path)\n'
  query+='\(if .fstype then "File System:   \(.fstype|ascii_upcase)\n" else "" end)'
  query+='Removable:     \(.rm)\n'
  query+='ReadOnly:      \(.ro)\n'
  query+='Transfer:      \(.tran)\n'
  query+='HotPlug:       \(.hotplug)\n'
  query+='Size:          \(.size)\n'
  query+='\(if .fsavail then "Free Space:    \(.fsavail)\n" else "" end)'
  query+='\(if .fsused then "Used Space:    \(.fsused) [\(."fsuse%")]\n" else "" end)'
  query+='\(if .label then "Label:         \(.label)\n" else "" end)'
  query+='\(if .uuid then "UUID:          \(.uuid)\n" else "" end)'
  query+='Vendor:        \(.vendor|if . and . != "" then . else "n/a" end)\n'
  query+='Model:         \(.model|if . and . != "" then . else "n/a" end)\n'
  query+='Revision:      \(.rev|if . and . != "" then . else "n/a" end)\n'
  query+='Serial:        \(.serial|if . and . != "" then . else "n/a" end)\n'
  query+='State:         \(.state|if . and . != "" then . else "n/a" end)'
  query+='\(if .mountpoint then "\nMount:         \(.mountpoint)" else "" end)'

  echo "${rom}" | jq -cer "\"${query}\"" || return 1
}

# Shows the list of disk block devices.
# Outputs:
#  A list of disk block devices.
list_disks () {
  local disks=''
  disks="$(find_disks)" || return 1

  local len=0
  len="$(get_len "${disks}")" || return 1

  if is_true "${len} = 0"; then
    log 'No disks have found.'
    return 0
  fi

  local query=''
  query+='Name:    \(.name)\n'
  query+='Path:    \(.path)\n'
  query+='Size:    \(.size)\n'
  query+='Vendor:  \(.vendor|if . and . != "" then . else "n/a" end)\n'
  query+='Model:   \(.model|if . and . != "" then . else "n/a" end)'
  query="[.[]|\"${query}\"]|join(\"\n\n\")"

  echo "${disks}" | jq -cer "${query}" || return 1
}

# Shows the list of partitions of the disk block device
# with the given path.
# Arguments:
#  disk: the path of a disk block device
# Outputs:
#  A list of parition block devices.
list_partitions () {
  local disk="${1}"

  if is_not_given "${disk}"; then
    on_script_mode &&
      log 'Missing the disk path.' && return 2

    pick_disk || return $?
    is_empty "${REPLY}" && log 'Disk path is required.' && return 2
    disk="${REPLY}"
  fi

  if is_not_disk "${disk}"; then
    log "Path ${disk} is not a disk device."
    return 2
  fi

  local parts=''
  parts="$(find_partitions "${disk}")" || return 1

  local len=0
  len="$(get_len "${parts}")" || return 1

  if is_true "${len} = 0"; then
    log 'No partitions have found.'
    return 0
  fi

  local query=''
  query+='Name:   \(.name)\(if .veracrypt then " [encrypted]" else "" end)\n'
  query+='Path:   \(.path)\n'
  query+='Size:   \(.size)'
  query+='\(if .label then "\nLabel:  \(.label)" else "" end)'
  query="[.[]|\"${query}\"]|join(\"\n\n\")"

  echo "${parts}" | jq -cer "${query}" || return 1
}

# Shows the list of rom block devices.
# Outputs:
#  A list of rom block devices.
list_roms () {
  local roms=''
  roms="$(find_roms)" || return 1

  local len=0
  len="$(get_len "${roms}")" || return 1

  if is_true "${len} = 0"; then
    log 'No roms have found.'
    return 0
  fi

  local query=''
  query+='Name:    \(.name)\n'
  query+='Path:    \(.path)\n'
  query+='Size:    \(.size)'
  query+='\(if .vendor then "\nVendor:  \(.vendor)" else "" end)'
  query+='\(if .model then "\nModel:   \(.model)" else "" end)'
  query+='\(if .label then "\nLabel:   \(.label)" else "" end)'
  query="[.[]|\"${query}\"]|join(\"\n\n\")"

  echo "${roms}" | jq -cer "${query}" || return 1
}

# Shows the list of shared folders of the given host.
# Arguments:
#  host:     the name or ip of a host
#  user:     the username
#  group:    the user group
#  password: the password
# Outputs:
#  A list of shared folders.
list_shared_folders () {
  local host="${1}"
  local user="${2}"
  local group="${3}"
  local password="${4}"

  if is_not_given "${host}"; then
    on_script_mode &&
      log 'Missing the host.' && return 2

    pick_host || return $?
    is_empty "${REPLY}" && log 'Host is required.' && return 2
    host="${REPLY}"
  fi

  if is_not_given "${user}"; then
    on_script_mode &&
      log 'Missing the username.' && return 2

    ask 'Enter the username:' || return $?
    is_empty "${REPLY}" && log 'Username is required.' && return 2
    user="${REPLY}"
  fi

  if is_not_given "${group}"; then
    on_script_mode &&
      log 'Missing the user group.' && return 2

    ask 'Enter the user group [WORKGROUP]:' || return $?
    group="${REPLY:-"WORKGROUP"}"
  fi

  if is_not_given "${password}"; then
    on_script_mode &&
      log 'Missing the password.' && return 2

    ask_secret 'Enter the password:' || return $?
    is_empty "${REPLY}" && log 'Password is required.' && return 2
    password="${REPLY}"
  fi

  local folders=''
  folders="$(find_shared_folders "${host}" "${user}" "${group}" "${password}")"

  if has_failed; then
    log 'Unable to find shared folders.'
    return 2
  fi

  local len=0
  len="$(get_len "${folders}")" || return 1

  if is_true "${len} = 0"; then
    log 'No shared folders have found.'
    return 0
  fi

  local query=''
  query+='Name:  \(.name)\n'
  query+='Type:  \(.type)'

  query="[.[]|\"${query}\"]|join(\"\n\n\")"

  echo "${folders}" | jq -cer "${query}" || return 1
}

# Shows the list of any mounted devices, images and/or
# shared folders.
# Outputs:
#  A list of mounting points.
list_mounts () {
  local mounts='[]'

  local disks=''
  disks="$(find_disks | jq -cer '.[]|.path')" || return 1

  local disk=''
  while read -r disk; do
    local parts=''
    parts="$(find_partitions "${disk}" mounted |
      jq -cer '[.[]|{name: .path, point: (if .mountpoint then .mountpoint else .veracrypt.mountpoint end)}]')" || return 1

    # Merge disk partitions to mounts array
    mounts="$(jq -n --argjson m "${mounts}" --argjson p "${parts}" '$m + $p')" || return 1
  done <<< "${disks}"

  local roms=''
  roms="$(find_roms mounted | 
    jq -cer '[.[]|{name: .path, point: .mountpoint}]')" || return 1
  
  # Merge roms to mounts array
  mounts="$(jq -n --argjson m "${mounts}" --argjson r "${roms}" '$m + $r')" || return 1

  local folders=''

  if directory_exists "/run/user/${UID}/gvfs"; then
    folders="$(ls "/run/user/${UID}/gvfs" | awk -v id="${UID}" '{
      match($0, /server=(.*),share=(.*),/, a);

      schema="\"name\": \"%s\","
      schema=schema"\"point\": \"%s\""
      schema="{"schema"},"

      printf schema, a[1]"/"a[2], "/run/user/"id"/gvfs/"$0
    }')" || return 1

    # Remove the extra comma after the last element
    folders="${folders:+${folders::-1}}"
  fi

  folders="[${folders}]"

  # Merge shared folders to mounts array
  mounts="$(jq -n --argjson m "${mounts}" --argjson f "${folders}" '$m + $f')" || return 1

  local images=''
  images="$(cat /proc/mounts | awk '/^fuseiso/{
    n=split($2, a, "/")

    schema="\"name\": \"%s\","
    schema=schema"\"point\": \"%s\""
    schema="{"schema"},"

    printf schema, a[n], $2
  }')" || return 1

  # Remove the extra comma after the last element
  images="${images:+${images::-1}}"

  images="[${images}]"

  # Merge images to mounts array
  mounts="$(jq -n --argjson m "${mounts}" --argjson i "${images}" '$m + $i')" || return 1

  local len=0
  len="$(get_len "${mounts}")" || return 1

  if is_true "${len} = 0"; then
    log 'No mounts have found.'
    return 0
  fi

  local query=''
  query+='Name:   \(.name)\n'
  query+='Point:  \(.point)'
  query="[.[]|\"${query}\"]|join(\"\n\n\")"

  echo "${mounts}" | jq -cer "${query}" || return 1
}

# Mounts the partition block device with the given path.
# Arguments:
#  path: the path of a partition block device
mount_partition () {
  local path="${1}"

  if is_not_given "${path}"; then
    on_script_mode &&
      log 'Missing the partition path.' && return 2

    pick_disk || return $?
    is_empty "${REPLY}" && log 'Disk path is required.' && return 2
    local disk="${REPLY}"

    pick_partition "${disk}" unmounted || return $?
    is_empty "${REPLY}" && log 'Partition path is required.' && return 2
    path="${REPLY}"
  fi

  if is_not_partition "${path}"; then
    log "Path ${path} is not a partition device."
    return 2
  elif is_mounted "${path}"; then
    log "Partition ${path} is already mounted."
    return 2
  fi

  mount_device "${path}"

  if has_failed; then
    log 'Failed to mount the partition.'
    return 2
  fi

  log "Partition ${path} mounted."
}

# Mounts the encrypted partition block device with
# the given path.
# Arguments:
#  path: the path of an encrypted partition
#  key:  the encryption key
mount_encrypted () {
  authenticate_user || return $?

  local path="${1}"
  local key="${2}"

  if is_not_given "${path}"; then
    on_script_mode &&
      log 'Missing the partition path.' && return 2

    pick_disk || return $?
    is_empty "${REPLY}" && log 'Disk path is required.' && return 2
    local disk="${REPLY}"

    pick_partition "${disk}" unmounted || return $?
    is_empty "${REPLY}" && log 'Partition path is required.' && return 2
    path="${REPLY}"
  fi

  if is_not_partition "${path}"; then
    log "Path ${path} is not a partition device."
    return 2
  elif is_mounted "${path}"; then
    log "Partition ${path} is already mounted."
    return 2
  fi

  if is_not_given "${key}"; then
    on_script_mode &&
      log 'Missing the encryption key.' && return 2

    ask_secret 'Enter the encryption key:' || return $?
    is_empty "${REPLY}" && log 'Encryption key is required.' && return 2
    key="${REPLY}"
  fi

  mount_encrypted_device "${path}" "${key}"

  if has_failed; then
    log 'Failed to mount encrypted partition.'
    return 2
  fi

  log "Encrypted partition ${path} mounted."
}

# Unmounts the partition block device with the
# given path.
# Arguments:
#  path: the path of a partition block device
unmount_partition () {
  local path="${1}"

  if is_not_given "${path}"; then
    on_script_mode &&
      log 'Missing the partition path.' && return 2

    pick_disk || return $?
    is_empty "${REPLY}" && log 'Disk path is required.' && return 2
    local disk="${REPLY}"

    pick_partition "${disk}" mounted || return $?
    is_empty "${REPLY}" && log 'Partition path is required.' && return 2
    path="${REPLY}"
  fi

  if is_not_partition "${path}"; then
    log "Path ${path} is not a partition device."
    return 2
  elif is_not_mounted "${path}"; then
    log "Partition ${path} is already unmounted."
    return 2
  elif is_system_partition "${path}"; then
    log 'Cannot unmount system partition.'
    return 2
  fi

  unmount_device "${path}"

  if has_failed; then
    log 'Failed to unmount partition.'
    return 2
  fi

  log "Partition ${path} unmounted."
}

# Unmounts the encrypted partition block device with the
# given path.
# Arguments:
#  path: the path of an encrypted partition
unmount_encrypted () {
  authenticate_user || return $?

  local path="${1}"

  if is_not_given "${path}"; then
    on_script_mode &&
      log 'Missing the partition path.' && return 2

    pick_disk || return $?
    is_empty "${REPLY}" && log 'Disk path is required.' && return 2
    local disk="${REPLY}"

    pick_partition "${disk}" mounted || return $?
    is_empty "${REPLY}" && log 'Partition path is required.' && return 2
    path="${REPLY}"
  fi

  if is_not_partition "${path}"; then
    log "Path ${path} is not a partition device."
    return 2
  elif is_not_mounted "${path}"; then
    log "Partition ${path} is already unmounted."
    return 2
  elif is_system_partition "${path}"; then
    log 'Cannot unmount system partition.'
    return 2
  fi

  unmount_encrypted_device "${path}"

  if has_failed; then
    log 'Failed to unmount encrypted partition.'
    return 2
  fi

  log "Encrypted partition ${path} unmounted."
}

# Mounts the rom block device with the given path.
# Arguments:
#  path: the path of a rom block device
mount_rom () {
  local path="${1}"

  if is_not_given "${path}"; then
    on_script_mode &&
      log 'Missing the rom path.' && return 2

    pick_rom unmounted || return $?
    is_empty "${REPLY}" && log 'Rom path is required.' && return 2
    path="${REPLY}"
  fi

  if is_not_rom "${path}"; then
    log "Path ${path} is not a rom device."
    return 2
  elif is_mounted "${path}"; then
    log "Rom ${path} is already mounted."
    return 2
  fi

  mount_device "${path}"

  if has_failed; then
    log 'Failed to mount rom.'
    return 2
  fi

  log "Rom ${path} mounted."
}

# Unmounts the rom block device with the given path.
# Arguments:
#  path: the path of a rom block device
unmount_rom () {
  local path="${1}"

  if is_not_given "${path}"; then
    on_script_mode &&
      log 'Missing the rom path.' && return 2

    pick_rom mounted || return $?
    is_empty "${REPLY}" && log 'Rom path is required.' && return 2
    path="${REPLY}"
  fi

  if is_not_rom "${path}"; then
    log "Path ${path} is not a rom device."
    return 2
  elif is_not_mounted "${path}"; then
    log "Rom ${path} is not mounted."
    return 2
  fi

  unmount_device "${path}"

  if has_failed; then
    log 'Failed to unmount rom.'
    return 2
  fi

  log "Rom ${path} unmounted."
}

# Mounts the image file system contained with in
# the file with the given file path.
# Arguments:
#  path: the path to an image file
mount_image () {
  local path="${1}"

  if is_not_given "${path}"; then
    log 'Image file path is required.'
    return 2
  elif file_not_exists "${path}"; then
    log "Path ${path} is not an image file."
    return 2
  fi

  local folder_name="$(basename "${path}")"
  local mount_point="${HOME}/mounts/virtual/${folder_name}"

  if directory_exists "${mount_point}"; then
    log "Image ${path} is already mounted."
    return 2
  fi

  mkdir -p "${mount_point}" &&
  fuseiso -p "${path}" "${mount_point}" &> /dev/null

  if has_failed; then
    log 'Failed to mount image file.'

    rm -rf "${mount_point}"
    return 2
  fi

  log "Image file ${path} mounted."
}

# Unmounts the image file system mounted to the given
# path.
# Arguments:
#  path: the path an image is mounted to
unmount_image () {
  local path="${1}"

  if is_not_given "${path}"; then
    on_script_mode &&
      log 'Missing the image mount path.' && return 2

    pick_image_mount || return $?
    is_empty "${REPLY}" && log 'Image mount path is required.' && return 2
    path="${REPLY}"
  fi

  if directory_not_exists "${path}"; then
    log 'No valid image mount path.'
    return 2
  fi

  fusermount -u "${path}"

  if has_failed; then
    log 'Failed to unmount image file system.'
    return 2
  fi

  rm -rf "${path}"

  log "Image file ${path} unmounted."
}

# Mounts a shared folder of the given host.
# Arguments:
#  host:     the name or ip of a host
#  name:     the name of the shared folder
#  user:     the username
#  group:    the group of the user
#  password: the password
mount_shared_folder () {
  local host="${1}"
  local name="${2}"
  local user="${3}"
  local group="${4}"
  local password="${5}"

  if is_not_given "${host}"; then
    on_script_mode &&
      log 'Missing the host.' && return 2

    pick_host || return $?
    is_empty "${REPLY}" && log 'Host is required.' && return 2
    host="${REPLY}"
  fi

  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Missing the folder name.' && return 2

    ask 'Enter a folder name:' || return $?
    is_empty "${REPLY}" && log 'Folder name is required.' && return 2
    name="${REPLY}"
  fi

  if is_not_given "${user}"; then
    on_script_mode &&
      log 'Missing the username.' && return 2

    ask 'Enter the username:' || return $?
    is_empty "${REPLY}" && log 'Username is required.' && return 2
    user="${REPLY}"
  fi

  if is_not_given "${group}"; then
    on_script_mode &&
      log 'Missing the user group.' && return 2
    
    ask 'Enter the user group [WORKGROUP]:' || return $?
    group="${REPLY:-"WORKGROUP"}"
  fi
  
  if is_not_given "${password}"; then
    on_script_mode &&
      log 'Missing the password.' && return 2

    ask_secret 'Enter the password:' || return $?
    is_empty "${REPLY}" && log 'Password is required.' && return 2
    password="${REPLY}"
  fi

  local uri="smb://${group};${user}@${host}/${name,,}"

  if gio mount -l | grep -q "${uri}"; then
    log "Shared folder ${name} is already mounted."
    return 2
  fi

  echo "${password}" | gio mount "${uri}" &> /dev/null
  
  if has_failed; then
    log 'Failed to mount shared folder.'
    return 2
  fi

  log "Shared folder ${name} mounted."

  local remote_home="${HOME}/mounts/remote"

  if directory_exists "/run/user/${UID}/gvfs" && symlink_not_exists "${remote_home}/gvfs"; then
    mkdir -p "${remote_home}"
    ln -s "/run/user/${UID}/gvfs" "${remote_home}"
  fi
}

# Unmounts the shared folder with the given uri.
# Arguments:
#  uri: the uri of a mount shared folder
unmount_shared_folder () {
  local uri="${1}"

  if is_not_given "${uri}"; then
    on_script_mode &&
      log 'Missing the mount uri.' && return 2

    pick_shared_folder_mount || return $?
    is_empty "${REPLY}" && log 'Mount uri is required.' && return 2
    uri="${REPLY}"
  fi
  
  gio mount -l | grep -q "${uri}"

  if has_failed; then
    log 'Shared folder is not mounted.'
    return 2
  fi

  sync && gio mount -u "${uri}" 2> /dev/null
  
  if has_failed; then
    log 'Failed to umount shared folder.'
    return 2
  fi

  log "Shared folder ${uri} unmounted."
}

# Formats the disk block device with the given path,
# creating a new partition table of a single primary
# partition.
# Arguments:
#  path:    the path of a disk block device
#  label:   the new label of the disk
#  fs_type: the new file system type  
format_disk () {
  authenticate_user || return $?

  local path="${1}"
  local label="${2}"
  local fs_type="${3}"

  if is_not_given "${path}"; then
    on_script_mode &&
      log 'Missing the disk path.' && return 2

    pick_disk || return $?
    is_empty "${REPLY}" && log 'Disk path is required.' && return 2
    path="${REPLY}"
  fi

  if is_not_disk "${path}"; then
    log "Path ${path} is not a disk device."
    return 2
  elif is_system_disk "${path}"; then
    log 'System disk cannot be formatted.'
    return 2
  fi

  if is_not_given "${label}"; then
    on_script_mode &&
      log 'Missing the disk label.' && return 2

    ask 'Enter the disk label:' || return $?
    is_empty "${REPLY}" && log 'Disk label is required.' && return 2
    label="${REPLY}"
  fi

  if is_not_given "${fs_type}"; then
    on_script_mode &&
      log 'Missing the file system type.' && return 2

    pick_fs_type || return $?
    is_empty "${REPLY}" && log 'File system type is required.' && return 2
    fs_type="${REPLY}"
  fi

  if is_not_valid_fs_type "${fs_type}"; then
    log 'Invalid or unknown file system type.'
    return 2
  fi

  # Do not ask confirmation on script mode
  if on_user_mode; then
    local query=''
    query+='\(.vendor|if . and . != "" then "\(gsub("^\\s+|\\s+$";"")) " else "disk " end)'
    query+='\(.model|if . and . != "" then "\(.) " else "" end)'
    query+='\(.size)'
    query="\"${query}\""

    local model=''
    model="$(find_disk "${path}" | jq -cr "${query}")" || return 1

    log "ALL DATA in ${model} [${path}],"
    log 'will be irreversibly gone forever!'
    confirm 'Do you really want to proceed?' || return $?
    is_empty "${REPLY}" && log 'Confirmation is required.' && return 2
    
    if is_not_yes "${REPLY}"; then
      log 'Format operation is canceled.'
      return 2
    fi
  fi

  log 'Unmounting disk partitions...'
  unmount_partitions "${path}" || return 1

  log 'Cleaning disk partitions...'
  clean_partitions "${path}" &&
  log 'Partition table is ready.' || return 1

  log 'Creating disk partition...'
  create_partition "${path}" "${fs_type}" 1Mib 100% &&
  log 'Primary partition created.' || return 1

  log 'Formatting disk partition...'
  format_partition "${path}" 1 "${fs_type}" "${label}"

  if has_failed; then
    log "Failed to format disk ${path}."
    return 2
  fi

  log "Disk ${path} has been formated."
}

# Ejects the disk block device with the given path.
# Arguments:
#  path: the path of a disk block device
eject_disk () {
  authenticate_user || return $?

  local path="${1}"

  if is_not_given "${path}"; then
    on_script_mode &&
      log 'Missing the disk path.' && return 2

    pick_disk || return $?
    is_empty "${REPLY}" && log 'Disk path is required.' && return 2
    path="${REPLY}"
  fi

  if is_not_disk "${path}"; then
    log "Path ${path} is not a disk device."
    return 2
  elif is_system_disk "${path}"; then
    log 'System disk cannot be ejected.'
    return 2
  fi

  log 'Unmounting disk partitions...'

  unmount_partitions "${path}"

  if has_failed; then
    log 'Failed to unmount disk partitions.'
    return 2
  fi

  udisksctl power-off -b "${path}" &> /dev/null

  if has_failed; then
    log 'Unable to power disk off.'
    log 'Unplug the disk device at your own risk.'
    return 0
  fi

  log 'Disk power set to off.'
  log 'Unplug safely the disk device.'
}

# Scans the disk block device with the given path
# for possible SMART data.
# Arguments:
#  path: the path of a disk block device
# Outputs:
#  A long list of health and status data.
scan_disk () {
  authenticate_user || return $?

  local path="${1}"

  if is_not_given "${path}"; then
    on_script_mode &&
      log 'Missing the disk path.' && return 2

    pick_disk || return $?
    is_empty "${REPLY}" && log 'Disk path is required.' && return 2
    path="${REPLY}"
  fi

  if is_not_disk "${path}"; then
    log "Path ${path} is not a disk device."
    return 2
  fi
  
  sudo smartctl -i "${path}" &> /dev/null
  
  if has_failed; then
    log 'Unable to retrieve SMART data.'
    return 2
  fi

  local model=''
  model+='if .model_name'
  model+=' then "\nModel:     \(.model_name) FW.\(.firmware_version)"'
  model+=' else ""'
  model+='end'

  local physicals=''
  physicals+='if .physical_block_size'
  physicals+=' then " P:\(.physical_block_size)"'
  physicals+=' else ""'
  physicals+='end'

  local factor=''
  factor+='if .form_factor.name'
  factor+=' then "\nFactor:    \(.form_factor.name) \(.rotation_rate) rpm"'
  factor+=' else ""'
  factor+='end'

  local sata=''
  sata+='if .sata_version.string'
  sata+=' then "\nSATA:      \(.sata_version.string) at \(.interface_speed.max.string)"'
  sata+=' else ""'
  sata+='end'

  local trim=''
  trim+='if .trim.supported'
  trim+=' then "\nTrim:      \(.trim.supported)"'
  trim+=' else ""'
  trim+='end'

  local passed=''
  passed+='if .smart_status.passed then "passed" else "failed" end'

  local temp=''
  temp+='if .temperature.current'
  temp+=' then "\nTemp:      \(.temperature.current)C"'
  temp+=' else ""'
  temp+='end'

  local attr=''
  attr+='Attr:      \(.id)\n'
  attr+='Name:      \(.name)\n'
  attr+='Raw:       \(.raw.value)\n'
  attr+='Values:    [V\(.value), W\(.worst), T\(.thresh)]\n'
  attr+='Failing:   \(.when_failed)'

  local attrs=''
  attrs+='.ata_smart_attributes.table as $a |'
  attrs+="if \$a then \"\n\n\([\$a[]|\"${attr}\"]|join(\"\n\n\"))\" else \"\" end"

  local query=''
  query+='Name:      \(.device.name)'
  query+="\(${model})"
  query+='\nProtocol:  \(.device.type|ascii_upcase) \(.device.protocol)'
  query+='\nCapacity:  \(.user_capacity.bytes) bytes'
  query+="\nBlocks:    L:\(.logical_block_size)\(${physicals})"
  query+="\(${factor})"
  query+="\(${trim})"
  query+="\(${sata})"
  query+='\nSMART:     \(.smart_support.enabled)'
  query+="\(${temp})"
  query+="\nHealth:    \(${passed})"
  query+="\(${attrs})"

  sudo smartctl -iHj "${path}" | jq -cer "\"${query}\""
}

# Creates an encrypted disk block device with the
# given path.
# Arguments:
#  path:    the path of a disk block device
#  fs_type: the new type of file system
#  key:     the encryption key
create_encrypted () {
  authenticate_user || return $?

  local path="${1}"
  local fs_type="${2}"
  local key="${3}"

  if is_not_given "${path}"; then
    on_script_mode &&
      log 'Missing the disk path.' && return 2

    pick_disk || return $?
    is_empty "${REPLY}" && log 'Disk path is required.' && return 2
    path="${REPLY}"
  fi

  if is_not_disk "${path}"; then
    log "Path ${path} is not a disk device."
    return 2
  elif is_system_disk "${path}"; then
    log 'System disk cannot be encrypted.'
    return 2
  fi

  if is_not_given "${fs_type}"; then
    on_script_mode &&
      log 'Missing the file system type.' && return 2

    pick_fs_type || return $?
    is_empty "${REPLY}" && log 'File system type is required.' && return 2
    fs_type="${REPLY}"
  fi

  if is_not_valid_fs_type "${fs_type}"; then
    log 'Invalid or unknown file system type.'
    return 2
  fi

  if is_not_given "${key}"; then
    on_script_mode &&
      log 'Missing the encryption key.' && return 2

    ask_secret 'Enter the encryption key:' || return $?
    is_empty "${REPLY}" && log 'Encryption key is required.' && return 2
    key="${REPLY}"
  fi

  if on_user_mode; then
    ask_secret 'Retype the encryption key:' || return $?

    if not_equals "${REPLY}" "${key}"; then
      log 'Encryption key does not match.'
      return 2
    fi

    local query=''
    query+='\(.vendor|if . and . != "" then "\(gsub("^\\s+|\\s+$";"")) " else "disk " end)'
    query+='\(.model|if . and . != "" then "\(.) " else "" end)'
    query+='\(.size)'
    query="\"${query}\""

    local model=''
    model="$(find_disk "${path}" | jq -cr "${query}")" || return 1

    log "ALL DATA in ${model} [${path}],"
    log 'will be irreversibly gone forever!'
    confirm 'Do you really want to proceed?' || return $?
    is_empty "${REPLY}" && log 'Confirmation is required.' && return 2
    
    if is_not_yes "${REPLY}"; then
      log 'Encryption operation is canceled.'
      return 2
    fi
  fi

  log 'Unmounting disk partitions...'
  unmount_partitions "${path}" || return 1

  log 'Cleaning disk partitions...'
  clean_partitions "${path}" &&
  log 'Partition table is ready.' || return 1

  log 'Creating disk partition...'
  create_partition "${path}" "${fs_type}" 1Mib 100% &&
  log 'Primary partition created.' || return 1

  log 'Formatting disk partition...'
  format_partition "${path}" 1 "${fs_type}" &&
  log "Partition ${path}1 has been formated." || return 1

  # Create a seed file with 350 random characters
  local rand_text_file="/tmp/.rand_text_$(date +%s)"

  tr -dc 'A-Za-z0-9!"#$%&'\''()*+,-./:;<=>?@[\]^_`{|}~' < /dev/urandom |
    head -c 350 > "${rand_text_file}"

  sudo veracrypt -t --create "${path}1" --password "${key}" \
    --volume-type normal --encryption AES --hash sha-512 --filesystem "${fs_type}" \
    --pim 0 --keyfiles '' --random-source "${rand_text_file}"

  if has_failed; then
    log 'Failed to encrypt disk.'
    return 2
  fi

  log "Disk ${path} has been encrypted."
}

# Creates a bootable archlinux installation drive.
# Arguments:
#  path:     the path of a disk block device
#  iso_file: the path to an archlinux iso file
create_bootable () {
  authenticate_user || return $?

  local path="${1}"
  local iso_file="${2}"

  if is_not_given "${path}"; then
    on_script_mode &&
      log 'Missing the disk path.' && return 2

    pick_disk || return $?
    is_empty "${REPLY}" && log 'Disk path is required.' && return 2
    path="${REPLY}"
  fi

  if is_not_disk "${path}"; then
    log "Path ${path} is not a disk device."
    return 2
  elif is_system_disk "${path}"; then
    log 'Cannot create bootable on the system disk.'
    return 2
  fi

  if is_not_given "${iso_file}"; then
    on_script_mode &&
      log 'Missing the iso file path.' && return 2

    confirm 'Do you want to download the latest iso?' || return $?
    is_empty "${REPLY}" && log 'Confirmation is required.' && return 2

    if is_yes "${REPLY}"; then
      pick_mirror || return $?
      is_empty "${REPLY}" && log 'Mirror is required.' && return 2
      local mirror="${REPLY}"

      local file_name='archlinux-x86_64.iso'
      local output_folder="${HOME}/downloads"

      download_iso_file "${mirror}" "${file_name}" "${output_folder}"

      if has_failed; then
        log 'Failed to download the iso file.'
        return 2
      fi

      log "ISO file saved to ${output_folder}/${file_name}."

      log "Verifying the ${file_name} file..."

      verify_iso_file "${output_folder}" "${file_name}"

      if has_failed; then
        log 'Failed to verify the iso file.'
        return 2
      fi

      log 'File has been verified successfully.'
      
      iso_file="${output_folder}/${file_name}"
    else
      ask 'Enter the path to the iso file:' || return $?
      is_empty "${REPLY}" && log 'File path is required.' && return 2
      iso_file="${REPLY}"
    fi
  fi

  if file_not_exists "${iso_file}"; then
    log 'Invalid or unknown iso file.'
    return 2
  fi

  if on_user_mode; then
    local query=''
    query+='\(.vendor|if . and . != "" then "\(gsub("^\\s+|\\s+$";"")) " else "disk " end)'
    query+='\(.model|if . and . != "" then "\(.) " else "" end)'
    query+='\(.size)'
    query="\"${query}\""

    local model=''
    model="$(find_disk "${path}" | jq -cr "${query}")" || return 1

    log "\nALL DATA in ${model} [${path}],"
    log 'will be irreversibly gone forever!'
    confirm 'Do you really want to proceed?' || return $?
    is_empty "${REPLY}" && log 'Confirmation is required.' && return 2
    
    if is_not_yes "${REPLY}"; then
      log 'Bootable operation is canceled.'
      return 2
    fi
  fi

  log 'Unmounting disk partitions...'
  unmount_partitions "${path}" || return 1

  log 'Cleaning disk partitions...'
  clean_partitions "${path}" &&
  log 'Partition table is ready.' || return 1

  log 'Creating disk partition...'
  create_partition "${path}" fat32 1Mib 100% &&
  log 'Primary partition created.' || return 1

  log 'Formatting the bootable disk...'
  format_partition "${path}" 1 fat32 || return 1

  log 'Flashing installation files...'

  sudo dd "if=${iso_file}" "of=${path}" bs=4M conv=fsync oflag=direct status=progress

  if has_failed; then
    log 'Failed to flash installation files.'
  fi

  log "Bootable disk ${path} is ready."
}

