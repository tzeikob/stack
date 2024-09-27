#!/bin/bash

source src/commons/process.sh
source src/commons/input.sh
source src/commons/auth.sh
source src/commons/error.sh
source src/commons/logger.sh
source src/commons/math.sh
source src/commons/validators.sh
source src/tools/disks/helpers.sh

# Shows a short status of the disks and filesystem.
# Outputs:
#  A list of disks and filesystem data.
show_status () {
  local space=9

  local alt_fstype='.children//[] | .[0].fstype | uppercase | dft("...")'
  local alt_fsuse='.children//[] | .[0]."fsuse%" | dft("...")'
  local parts=".[] | \"\(.path) \(.fstype//${alt_fstype}) \(.\"fsuse%\"//${alt_fsuse})\""

  local query=''
  query+='\(.path                      | lbln("Disk"))'
  query+='\(.vendor | trim             | lbln("Vendor"))'
  query+='\(.model                     | lbln("Model"))'
  query+='\(.size                      | lbln("Size"))'
  query+="\(.children//[] | [${parts}] | tree("Parts"; "None"))"

  query="[.[] | \"${query}\"] | join(\"\n\n\")"

  find_disks | jq -cer --arg SPC ${space} "${query}" || return 1

  echo

  swapon --noheadings --show | awk -F' ' -v SPC=${space} '{
    frm="%-"SPC"s%s\n"

    printf frm, "Swap:", $1
    printf frm, "Type:", $2
    printf frm, "Used:", $4"/"$3
  }' || return 1

  cat /proc/meminfo | grep -E 'Swap.*' | awk -F':' -v SPC=${space} '{
    gsub(/^[ \t]+/,"",$1)
    gsub(/[ \t]+$/,"",$1)
    gsub(/^[ \t]+/,"",$2)
    gsub(/[ \t]+$/,"",$2)

    if ($1 == "SwapCached") $1="Cached"
    if ($1 == "SwapTotal") $1="Total"
    if ($1 == "SwapFree") $1="Free"

    frm="%-"SPC"s%s\n"

    printf frm, $1":", $2
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

  local alt_fstype='.children//[] | .[0].fstype | uppercase | dft("...")'
  local alt_fsuse='.children//[] | .[0]."fsuse%" | dft("...")'
  local alt_label='.children//[] | .[0].label | dft("...")'
  local parts=".[] | \"\(.path) \(.fstype//${alt_fstype}) \(.\"fsuse%\"//${alt_fsuse} \(.label//${alt_label}))\""

  local query=''
  query+='\(.name                       | lbln("Name"))'
  query+='\(.path                       | lbln("Path"))'
  query+='\(.rm                         | lbln("Removable"))'
  query+='\(.ro                         | lbln("ReadOnly"))'
  query+='\(.tran                       | lbln("Transfer"))'
  query+='\(.hotplug                    | lbln("HotPlug"))'
  query+='\(.size                       | lbln("Size"))'
  query+='\(.vendor | trim              | lbln("Vendor"))'
  query+='\(.model                      | lbln("Model"))'
  query+='\(.rev                        | lbln("Revision"))'
  query+='\(.serial                     | lbln("Serial"))'
  query+='\(.state                      | lbln("State"))'
  query+="\(.children//[] | [${parts}]  | tree("Parts"; "None")"

  echo "${disk}" | jq -cer --arg SPC 12 "\"${query}\"" || return 1
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

  local alt_fstype='.children//[] | .[0].fstype | opt'
  local alt_fsavail='.children//[] | .[0].fsavail | opt'
  local alt_fsused='.children//[] | .[0].fsused | opt'
  local alt_util='.children//[] | .[0]."fsuse%" | opt'
  local alt_label='.children//[] | .[0].label | opt'
  local alt_uuid='.children//[] | .[0].uuid | opt'

  local query=''
  query+='\(.name                                  | lbln("Name"))'
  query+='\(.path                                  | lbln("Path"))'
  query+="\(.mountpoint//.veracrypt.mountpoint     | olbln("Mount"))"
  query+="\(.fstype//${alt_fstype} | uppercase     | lbln(\"File System\"))"
  query+='\(.rm                                    | lbln("Removable"))'
  query+='\(.ro                                    | lbln("ReadOnly"))'
  query+='\(.hotplug                               | lbln("HotPlug"))'
  query+="\(.label//${alt_label}                   | lbln("Label"))"
  query+="\(.uuid//${alt_uuid}                     | lbln("UUID"))"
  query+='\(if .veracrypt then "yes" else "no" end | olbln("Encrypted"))'
  query+='\(.veracrypt.encryption_algo             | olbln("Encryption"))'
  query+='\(.veracrypt.slot                        | olbln("Slot"))'
  query+='\(.veracrypt.hidden_protected            | olbln("Hidden"))'
  query+='\(.veracrypt.prf                         | olbln("PRF"))'
  query+='\(.veracrypt.mode                        | olbln("Mode"))'
  query+='\(.veracrypt.block_size                  | olbln("Block"))'
  query+='\(.veracrypt.device                      | olbln("Mapped"))'
  query+='\(.size                                  | lbln("Size"))'
  query+="\(.fsavail//${alt_fsavail}               | lbln(\"Free Space\"))"
  query+="\(.fsused//${alt_fsused}                 | lbln(\"Used Space\"))"
  query+="\(.\"fsuse%\"//${alt_util}               | lbl("Utilization"))"

  echo "${part}" | jq -cer -arg SPC 14 "\"${query}\"" || return 1
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
  query+='\(.name               | lbln("Name"))'
  query+='\(.path               | lbln("Path"))'
  query+='\(.mountpoint         | olbl("Mount"))'
  query+='\(.fstype | uppercase | lbln("File System"; "Unknown"))'
  query+='\(.rm                 | lbln("Removable"))'
  query+='\(.ro                 | lbln("ReadOnly"))'
  query+='\(.tran               | lbln("Transfer"))'
  query+='\(.hotplug            | lbln("HotPlug"))'
  query+='\(.label              | olbln("Label"))'
  query+='\(.uuid               | olbln("UUID"))'
  query+='\(.vendor | trim      | lbln("Vendor"))'
  query+='\(.model              | lbln("Model"))'
  query+='\(.rev                | lbln("Revision"))'
  query+='\(.serial             | lbln("Serial"))'
  query+='\(.size               | olbln("Size"))'
  query+='\(.fsavail            | olbln("Free Space"))'
  query+='\(.fsused             | olbln("Used Space"))'
  query+='\(."fsuse%"           | olbln("Utilization"))'
  query+='\(.state              | lbl("State"))'

  echo "${rom}" | jq -cer --arg SPC 14 "\"${query}\"" || return 1
}

# Shows the list of disk block devices.
# Outputs:
#  A list of disk block devices.
list_disks () {
  local disks=''
  disks="$(find_disks)" || return 1

  local len=0
  len="$(echo "${disks}" | jq -cer 'length')" || return 1

  if is_true "${len} = 0"; then
    log 'No disks have found.'
    return 0
  fi

  local query=''
  query+='\(.name          | lbln("Name"))'
  query+='\(.path          | lbln("Path"))'
  query+='\(.vendor | trim | olbln("Vendor"))'
  query+='\(.model         | olbln("Model"))'
  query+='\(.size          | lbl("Size"))'

  query="[.[] | \"${query}\"] | join(\"\n\n\")"

  echo "${disks}" | jq -cer --arg SPC 9 "${query}" || return 1
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
  len="$(echo "${parts}" | jq -cer 'length')" || return 1

  if is_true "${len} = 0"; then
    log 'No partitions have found.'
    return 0
  fi

  local query=''
  query+='\(.name                                  | lbln("Name"))'
  query+='\(if .veracrypt then "yes" else "no" end | olbln("Encrypted"))'
  query+='\(.path                                  | lbln("Path"))'
  query+='\(.label                                 | olbln("Label))'
  query+='\(.size                                  | lbl("Size"))'

  query="[.[] | \"${query}\"] | join(\"\n\n\")"

  echo "${parts}" | jq -cer --arg 12 "${query}" || return 1
}

# Shows the list of rom block devices.
# Outputs:
#  A list of rom block devices.
list_roms () {
  local roms=''
  roms="$(find_roms)" || return 1

  local len=0
  len="$(echo "${roms}" | jq -cer 'length')" || return 1

  if is_true "${len} = 0"; then
    log 'No roms have found.'
    return 0
  fi

  local query=''
  query+='\(.name          | lbln("Name"))'
  query+='\(.path          | lbln("Path"))'
  query+='\(.vendor | trim | olbln("Vendor"))'
  query+='\(.model         | olbln("Model"))'
  query+='\(.label         | olbln("Label"))'
  query+='\(.size          | lbl("Size"))'
  
  query="[.[] | \"${query}\"] | join(\"\n\n\")"

  echo "${roms}" | jq -cer --arg SPC 9 "${query}" || return 1
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
  len="$(echo "${folders}" | jq -cer 'length')" || return 1

  if is_true "${len} = 0"; then
    log 'No shared folders have found.'
    return 0
  fi

  local query=''
  query+='\(.name | lbln("Name"))'
  query+='\(.type | lbl("Type"))'

  query="[.[] | \"${query}\"] | join(\"\n\n\")"

  echo "${folders}" | jq -cer --arg SPC 7 "${query}" || return 1
}

# Shows the list of any mounted devices, images and/or
# shared folders.
# Outputs:
#  A list of mounting points.
list_mounts () {
  local mounts='[]'

  local disks=''
  disks="$(find_disks | jq -cer '.[] | .path')" || return 1

  local disk=''
  while read -r disk; do
    local parts=''
    parts="$(find_partitions "${disk}" mounted |
      jq -cer '[.[] | {name: .path, point: .mountpoint//.veracrypt.mountpoint}]')" || return 1

    # Merge disk partitions to mounts array
    mounts="$(jq -n --argjson m "${mounts}" --argjson p "${parts}" '$m + $p')" || return 1
  done <<< "${disks}"

  local roms=''
  roms="$(find_roms mounted | 
    jq -cer '[.[] | {name: .path, point: .mountpoint}]')" || return 1
  
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
  len="$(echo "${mounts}" | jq -cer 'length')" || return 1

  if is_true "${len} = 0"; then
    log 'No mounts have found.'
    return 0
  fi

  local query=''
  query+='\(.name  | lbln("Name"))'
  query+='\(.point | lbl("Point"))'

  query="[.[] | \"${query}\"] | join(\"\n\n\")"

  echo "${mounts}" | jq -cer --arg SPC 7 "${query}" || return 1
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

  local folder_name=''
  folder_name="$(basename "${path}")"
  
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
    query+='\(.vendor | trim | dft("disk")) '
    query+='\(.model         | dft("...")) '
    query+='\(.size          | dft("..."))'

    local model=''
    model="$(find_disk "${path}" | jq -cr "\"${query}"\")" || return 1

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

  local attr=''
  attr+='\(.id          | lbln("ID"))'
  attr+='\(.name        | lbln("Name"))'
  attr+='\(.raw.value   | lbln("Raw"))'
  attr+='\(.value       | lbln("Value"))'
  attr+='\(.worst       | lbln("Worst"))'
  attr+='\(.thresh      | lbln("Threshold))'
  attr+='\(.when_failed | lbl("Failing"))'

  local attrs=''
  attrs+=".ata_smart_attributes.table//[] | [.[] | \"\n\n\(\"${attr}\")\"] | join(\"\n\n\")"

  local query=''
  query+='\(.device.name                | lbln("Name"))'
  query+='\(.model_name                 | olbln("Model"))'
  query+='\(.firmware_version           | olbln("Firmware"))'
  query+='\(.device.type | uppercase    | lbln("Type"))'
  query+='\(.device.protocol            | lbln("Protocol"))'
  query+='\(.user_capacity.bytes        | lbln("Capacity"))'
  query+='\(.logical_block_size         | olbln("LBS"))'
  query+='\(.physical_block_size        | olbln("PBS"))'
  query+='\(.form_factor.name           | olbln("Factor"))'
  query+='\(.rotation_rate              | olbln("RPM"))'
  query+='\(.trim.supported             | olbln("Trim"))'
  query+='\(.sata_version.string        | olbln("SATA"))'
  query+='\(.interface_speed.max.string | olbln("Speed"))'
  query+='\(.smart_support.enabled      | olbln("SMART"))'
  query+='\(.temperature.current        | olbln("Celsius"))'
  query+='\(.smart_status.passed        | lbl("Passed"))'
  query+="\(${attrs})"

  sudo smartctl -iHj "${path}" | jq -cer --arg SPC 12 "\"${query}\""
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
    query+='\(.vendor | trim | dft("disk")) '
    query+='\(.model         | dft("...")) '
    query+='\(.size          | dft("..."))'

    local model=''
    model="$(find_disk "${path}" | jq -cr "\"${query}\"")" || return 1

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
    query+='\(.vendor | trim | dft("disk")) '
    query+='\(.model         | dft("...")) '
    query+='\(.size          | dft("..."))'

    local model=''
    model="$(find_disk "${path}" | jq -cr "\"${query}\"")" || return 1

    log -n "ALL DATA in ${model} [${path}],"
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

