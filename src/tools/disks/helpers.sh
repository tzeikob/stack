#!/bin/bash

source src/commons/input.sh
source src/commons/error.sh
source src/commons/logger.sh
source src/commons/network.sh
source src/commons/math.sh
source src/commons/validators.sh

# Returns the list of disk block devices.
# Outputs:
#  A json array of disk block device objects.
find_disks () {
  local fields='name,path,type,size,rm,ro,tran,hotplug,state,'
  fields+='vendor,model,rev,serial,mountpoint,mountpoints,'
  fields+='label,uuid,fstype,fsver,fsavail,fsused,fsuse%'

  local query='[.blockdevices[] | select(.type == "disk")]'

  lsblk -J -o "${fields}" | jq -cer "${query}" || return 1
}

# Returns the disk block device with the given path.
# Arguments:
#  path: the path of a disk block device
# Outputs:
#  A json object of a disk block device.
find_disk () {
  local path="${1}"

  if is_not_block_device "${path}"; then
    return 1
  fi

  local query=".[] | select(.path == \"${path}\")"

  find_disks | jq -cer "${query}" || return 1
}

# Returns the list of partitions of the disk block
# device with the given path.
# Arguments:
#  path:   the path of a disk block device
#  status: mounted or unmounted
# Outputs:
#  A json array of partition block device objects.
find_partitions () {
  local path="${1}"
  local status="${2}"

  if is_not_block_device "${path}"; then
    return 1
  fi

  # Collect any disk partitions reported by lsblk
  local query=''
  query+='.children | if . then .[] | select(.type == "part") else empty end'
  query="[${query}]"

  local parts=''
  parts="$(find_disk "${path}" | jq -cer "${query}")" || return 1

  # Collect any disk encrypted volumes reported by veracrypt
  local volumes=''
  volumes="$(veracrypt -t --list 2>&1)"

  if has_failed && not_match "${volumes}" 'No volumes mounted'; then
    return 1
  fi

  local query="[.[] | select(.path | test(\"^${path}\")) | {path: .path, veracrypt: .}]"

  volumes="$(echo "${volumes}" | jc --veracrypt | jq -cer "${query}")" || return 1

  # Merge partitions and volumes data by path into an array
  local query='$p + $v | group_by(.path) | map(add)'

  if equals "${status}" 'mounted'; then
    query+='| .[] | select(.mountpoint != null or .veracrypt.mountpoint != null)'
  elif equals "${status}" 'unmounted'; then
    query+='| .[] | select(.mountpoint == null and .veracrypt.mountpoint == null)'
  fi

  query="[${query}] | flatten"

  jq -ncer --argjson p "${parts}" --argjson v "${volumes}" "${query}" || return 1
}

# Returns the partition block device with the given path.
# Arguments:
#  path: the path of a partition block device
# Outputs:
#  A json object of a partition block device.
find_partition () {
  local path="${1}"

  if is_not_block_device "${path}"; then
    return 1
  fi

  # Collect the partition data reported by lsblk
  local fields='name,path,type,size,rm,ro,tran,hotplug,state,'
  fields+='vendor,model,rev,serial,mountpoint,mountpoints,'
  fields+='label,uuid,fstype,fsver,fsavail,fsused,fsuse%'

  local query='.blockdevices[0] | select(.type == "part")'

  local part=''
  part="$(lsblk -J -o "${fields}" "${path}" | jq -cer "${query}")" || return 1

  # Colect the encrypted volume data reported by veracrypt, if any
  local volume=''
  volume="$(veracrypt -t --volume-properties "${path}" 2>&1)"

  if has_failed && not_match "${volume}" 'No such volume is mounted'; then
    return 1
  fi

  local query='if . | length > 0 then .[0] | {path: .path, veracrypt: .} else {} end'

  volume="$(echo "${volume}" | jc --veracrypt | jq -cer "${query}")" || return 1

  # Merge partition and volume data into an object
  jq -ncer --argjson p "${part}" --argjson v "${volume}" '$p + $v' || return 1
}

# Returns the list of rom block devices.
# Arguments:
#  status: mounted or unmounted
# Outputs:
#  A json array of rom block device objects.
find_roms () {
  local status="${1}"

  local fields='name,path,type,size,rm,ro,tran,hotplug,state,'
  fields+='vendor,model,rev,serial,mountpoint,mountpoints,'
  fields+='label,uuid,fstype,fsver,fsavail,fsused,fsuse%'

  local query='.blockdevices[] | select(.type == "rom")'

  if equals "${status}" 'mounted'; then
    query+='| select(.mountpoint != null)'
  elif equals "${status}" 'unmounted'; then
    query+='| select(.mountpoint == null)'
  fi

  query="[${query}]"

  lsblk -J -o "${fields}" | jq -cer "${query}" || return 1
}

# Returns the rom block device with the given path.
# Arguments:
#  path: the path of a rom block device
# Outputs:
#  A json object of a rom block device.
find_rom () {
  local path="${1}"

  if is_not_block_device "${path}"; then
    return 1
  fi

  local query=".[] | select(.path == \"${path}\")"

  find_roms | jq -cer "${query}" || return 1
}

# Checks if the block device with the given path
# is a disk device.
# Arguments:
#  path: the path of a block device
# Returns:
#  0 if it is disk otherwise 1.
is_disk () {
  local path="${1}"

  if is_not_block_device "${path}"; then
    return 1
  fi

  local type=''
  type="$(find_disk "${path}" | jq -cer '.type')" || return 1

  if equals "${type}" 'disk'; then
    return 0
  else
    return 1
  fi
}

# An inverse version of is_disk.
is_not_disk () {
  is_disk "${1}" && return 1 || return 0
}

# Checks if the block device with the given path
# is a disk with system partitions on it.
# Arguments:
#  path: the path of a disk block device
# Returns:
#  0 if it is a system disk otherwise 1.
is_system_disk () {
  local path="${1}"

  if is_not_block_device "${path}"; then
    return 1
  fi

  local disk=''
  disk="$(find_disk "${path}")" || return 1

  local system_paths='/ | /home | /boot | /var | /log | /swap'

  # Check if any partition's mountpoint is a system path
  local is_system_path="if . then . | test(\"^(${system_paths})$\") else false end"

  local query=''
  query+=".children | if . then [.[] | .mountpoint | ${is_system_path}] | any else false end"

  local result=''
  result="$(echo "${disk}" | jq -cr "${query}")" || return 1

  if is_true "${result}"; then
    return 0
  fi

  # Check also deep into the partitions children, if any
  local query=''
  query+=".children | if . then [.[] | .mountpoint | ${is_system_path}] | any else false end"
  query=".children | if . then ([.[] | ${query}] | any) else false end"

  result="$(echo "${disk}" | jq -cr "${query}")" || return 1

  if is_true "${result}"; then
    return 0
  else
    return 1
  fi
}

# An inverse version of is_system_disk.
is_not_system_disk () {
  is_system_disk "${1}" && return 1 || return 0
}

# Checks if the block device with the given path
# is a partition device.
# Arguments:
#  path: the path of a block device
# Returns:
#  0 if it is partition otherwise 1.
is_partition () {
  local path="${1}"

  if is_not_block_device "${path}"; then
    return 1
  fi

  local type=''
  type="$(find_partition "${path}" | jq -cer '.type')" || return 1

  if equals "${type}" 'part'; then
    return 0
  else
    return 1
  fi
}

# An inverse version of is_partition.
is_not_partition () {
  is_partition "${1}" && return 1 || return 0
}

# Checks if the block device with the given path
# is a partition pointing to a system path.
# Arguments:
#  path: the path of a partition block device
# Returns:
#  0 if it is a system partition otherwise 1.
is_system_partition () {
  local path="${1}"

  if is_not_block_device "${path}"; then
    return 1
  fi

  local system_paths='/ | /home | /boot | /var | /log | /swap'

  # Check if partition mountpoint is a system path
  local is_system_path="if . then . | test(\"^(${system_paths})$\") else false end"

  local query=''
  query+="if (.mountpoint | ${is_system_path}) or (.veracrypt.mountpoint | ${is_system_path})"
  query+=' then true else false '
  query+='end'

  local result=''
  result="$(find_partition "${path}" | jq -cer "${query}")" || return 1

  if is_true "${result}"; then
    return 0
  else
    return 1
  fi
}

# An inverse version of is_system_partition.
is_not_system_partition () {
  is_system_partition "${1}" && return 1 || return 0
}

# Checks if the block device with the given path
# is a rom device.
# Arguments:
#  path: the path of a block device
# Returns:
#  0 if it is rom otherwise 1.
is_rom () {
  local path="${1}"

  if is_not_block_device "${path}"; then
    return 1
  fi

  local type=''
  type="$(find_rom "${path}" | jq -cer '.type')" || return 1

  if equals "${type}" 'rom'; then
    return 0
  else
    return 1
  fi
}

# An inverse version of is_rom.
is_not_rom () {
  is_rom "${1}" && return 1 || return 0
}

# Checks if the block device with the given path
# is mounted or not.
# Arguments:
#  path: the path of a mountable block device
# Returns:
#  0 if it is mounted otherwise 1.
is_mounted () {
  local path="${1}"

  if is_not_block_device "${path}"; then
    return 1
  fi

  if grep -qsE "^${path} " /proc/mounts; then
    return 0
  fi

  if veracrypt -t --list 2>&1 | grep -qsE "^[0-9]+: ${path} "; then
    return 0
  fi

  return 1
}

# An inverse version of is_mounted.
is_not_mounted () {
  is_mounted "${1}" && return 1 || return 0
}

# Mounts the block device with the given path.
# Arguments:
#  path: the path of a mountable block device
mount_device () {
  local path="${1}"

  if is_not_block_device "${path}"; then
    return 1
  fi

  udisksctl mount -b "${path}" &> /dev/null || return 1

  # Create symlink to the local mount folder
  local local_home="${HOME}/mounts/local"

  if directory_exists "/run/media/${USER}" && symlink_not_exists "${local_home}/${USER}"; then
    mkdir -p "${local_home}"
    ln -s "/run/media/${USER}" "${local_home}"
  fi
}

# Mounts the encrypted block device with the given path.
# Arguments:
#  path: the path of an encrypted block device
#  key:  the encryption key
mount_encrypted_device () {
  local path="${1}"
  local key="${2}"

  if is_not_block_device "${path}"; then
    return 1
  fi

  local folder_name=''
  folder_name="$(echo "${path:1}" | tr '/' '_')"

  local mount_point="${HOME}/mounts/encrypted/${folder_name}"

  mkdir -p "${mount_point}" &&
  sudo veracrypt -t --mount "${path}" "${mount_point}" --password "${key}" \
    --pim 0 --keyfiles '' --protect-hidden no --non-interactive &> /dev/null

  if has_failed; then
    rm -rf "${mount_point}"
    return 1
  fi
}

# Unmounts the block device with the given path.
# Arguments:
#  path: the path of a mountable block device
unmount_device () {
  local path="${1}"

  if is_not_block_device "${path}"; then
    return 1
  fi

  sync &&
  udisksctl unmount -b "${path}" &> /dev/null || return 1
}

# Unmounts the encrypted block device with the given path.
# Arguments:
#  path: the path of an encrypted block device
unmount_encrypted_device () {
  local path="${1}"

  if is_not_block_device "${path}"; then
    return 1
  fi

  sync &&
  sudo veracrypt -t --dismount "${path}" &> /dev/null || return 1

  local folder_name=''
  folder_name="$(echo "${path:1}" | tr '/' '_')"

  rm -rf "${HOME}/mounts/encrypted/${folder_name}"
}

# Unmounts the mounted partitions of a disk block
# device with the given path.
# Arguments:
#  path: the path of a disk block device
unmount_partitions () {
  local path="${1}"

  if is_not_block_device "${path}"; then
    return 1
  fi

  # Collect any disk's mounted partitions
  local parts=''
  parts="$(grep -sE "^${path}p?[0-9]+ " /proc/mounts | awk '{print $1}')"

  # Collect any disk's mounted encrypted volumes, if any
  local volumes=''
  volumes="$(veracrypt -t --list 2>&1)"
  
  if has_failed && not_match "${volumes}" 'No volumes mounted'; then
    return 1
  fi
  
  volumes="$(echo "${volumes}" | jc --veracrypt | jq -cr '.[] | .path')" || return 1
  
  if is_empty "${parts}" && is_empty "${volumes}"; then
    log 'No mounted partitions found.'
    return 0
  fi

  if is_not_empty "${parts}"; then
    local part=''
    while read -r part; do
      unmount_device "${part}"

      if has_failed; then
        log "Failed to unmount partition ${part}."
        return 2
      fi
    
      log "Partition ${part} has been unmounted."
    done <<< "${parts}"
  fi

  if is_not_empty "${volumes}"; then
    local volume=''
    while read -r volume; do
      unmount_encrypted_device "${volume}"

      if has_failed; then
        log "Failed to unmount partition ${volume}."
        return 2
      fi
      
      log "Partition ${volume} has been unmounted."
    done <<< "${volumes}"
  fi
}

# Re-creates the partition table and removes any
# existing partitions on the disk block device with
# the given path.
# Arguments:
#  path: the path of a disk block device
clean_partitions () {
  local path="${1}"

  if is_not_block_device "${path}"; then
    return 1
  fi

  sudo wipefs --all --force --quiet "${path}" &&
  sudo parted --script -a optimal -- "${path}" mklabel msdos || return 1
}

# Creates a primary partition to the disk block
# device with the given path.
# Arguments:
#  path:    the path of a block disk device
#  fs_type: the fs type of the partition
#  start:   the start of the partition
#  end:     the end of the partition
create_partition () {
  local path="${1}"
  local fs_type="${2}"
  local start="${3}"
  local end="${4}"

  if is_not_block_device "${path}"; then
    return 1
  fi

  # Use ntfs as fs type for exfat file systems
  if equals "${fs_type}" 'exfat'; then
    fs_type='ntfs'
  fi
  
  sudo parted --script -a optimal -- "${path}" mkpart primary "${fs_type}" "${start}" "${end}" &&
  sudo parted --script -- "${path}" align-check optimal 1 || return 1
}

# Formats the i-th partition of the disk block
# device with the given path.
# Arguments:
#  path:    the path of a disk block device
#  index:   the index of the partition to format
#  fs_type: the fs type of the partition
#  label:   the label of the partition
format_partition () {
  local path="${1}"
  local index="${2}"
  local fs_type="${3}"
  local label="${4}"

  if is_not_block_device "${path}"; then
    return 1
  fi

  # Add path postfix for nvme and mmcblk disks
  if match "${path}" '^/dev/(nvme|mmcblk)'; then
    path="${path}p"
  fi

  case "${fs_type}" in
    ext2) sudo mkfs.ext2 -L "${label}" "${path}${index}" | awk NF;;
    ext3) sudo mkfs.ext3 -L "${label}" "${path}${index}" | awk NF;;
    ext4) sudo mkfs.ext4 -L "${label}" "${path}${index}" | awk NF;;
    ntfs) sudo mkfs.ntfs -f -L "${label}" "${path}${index}" | awk NF;;
    exfat) sudo mkfs.exfat -L "${label}" "${path}${index}" | awk NF;;
    fat32) sudo mkfs.fat -F 32 -n "${label}" "${path}${index}" | awk NF;;
    *) return 1;;
  esac

  if has_failed; then
    return 1
  fi
}

# Returns the list of shared folders of the given
# host available in the local network.
# Arguments:
#  host:     the name or ip of a host
#  user:     the name of the user
#  group:    the group of the user
#  password: the password of the user
# Outputs:
#  A json array of shared folder objects.
find_shared_folders () {
  local host="${1}"
  local user="${2}"
  local group="${3}"
  local password="${4}"

  local folders=''
  folders="$(smbclient -L "${host}" -U "${user}" -W "${group}" --password="${password}" |
    awk '/Disk/{print "{\"name\":\""$1"\",\"type\":\""$2"\"},"}')" || return 1

  # Remove the extra comma after the last element
  folders="${folders:+${folders::-1}}"

  echo "[${folders}]"
}

# Shows a menu asking the user to select one
# disk block device.
# Outputs:
#  A menu of disk block devices.
pick_disk () {
  local disks=''
  disks="$(find_disks)" || return 1

  local len=0
  len="$(echo "${disks}" | jq -cer 'length')" || return 1
  
  if is_true "${len} = 0"; then
    log 'No disks have found.'
    return 2
  fi

  local option='{key: .path, value: "\(.path) \(.vendor | trim | dft("...")) \(.size | dft("..."))"}'

  local query="[.[] | ${option}]"

  disks="$(echo "${disks}" | jq -cer "${query}")" || return 1

  pick_one 'Select a disk path:' "${disks}" vertical || return $?
}

# Shows a menu asking the user to select one partition
# of the disk with the given path.
# Arguments:
#  path:   the path of a disk block device
#  status: mounted, unmounted
# Outputs:
#  A menu of partition block devices.
pick_partition () {
  local path="${1}"
  local status="${2}"

  local parts=''
  parts="$(find_partitions "${path}" "${status}")" || return 1

  local len=0
  len="$(echo "${parts}" | jq -cer 'length')" || return 1
  
  if is_true "${len} = 0"; then
    log -e "No ${status:-\b} partitions have found."
    return 2
  fi

  local option='{key: .path, value: "\(.path) \(.label | trim | dft("...")) \(.size | dft("..."))"}'

  local query="[.[] | ${option}]"

  parts="$(echo "${parts}" | jq -cer "${query}")" || return 1

  pick_one 'Select a partition path:' "${parts}" vertical || return $?
}

# Shows a menu asking the user to select one rom block
# device.
# Arguments:
#  status: mounted, unmounted
# Outputs:
#  A menu of rom block devices.
pick_rom () {
  local status="${1}"

  local roms=''
  roms="$(find_roms "${status}")" || return 1

  local len=0
  len="$(echo "${roms}" | jq -cer 'length')" || return 1
  
  if is_true "${len} = 0"; then
    log "No ${status:-\b} roms have found."
    return 2
  fi

  local option='{key: .path, value: "\(.path) \(.vendor | trim | dft("...")) \(.label | trim | dft("...")) \(.size | dft("..."))"}'

  local query="[.[] | ${option}]"

  roms="$(echo "${roms}" | jq -cer "${query}")" || return 1

  pick_one 'Select a rom path:' "${roms}" vertical || return $?
}

# Shows a menu asking the user to select one host.
# Outputs:
#  A menu of host names.
pick_host () {
  log 'Searching hosts in local network...'

  local hosts=''
  hosts="$(find_hosts)"

  if has_failed; then
    log 'Unable to find hosts.'
    return 2
  fi

  local len=0
  len="$(echo "${hosts}" | jq -cer 'length')" || return 1
  
  if is_true "${len} = 0"; then
    log 'No hosts have found.'
    return 2
  fi

  local option='{key: .ip, value: "\(.ip) [\(.name | dft("..."))]"}'

  local query="[.[] | ${option}]"

  hosts="$(echo "${hosts}" | jq -cer "${query}")" || return 1

  pick_one 'Select a host:' "${hosts}" vertical || return $?
}

# Shows a menu asking the user to select one file system type.
# Outputs:
#  A menu of file system types.
pick_fs_type () {
  local values=''
  values+='{"key": "ext4", "value": "EXT4"},'
  values+='{"key": "ext3", "value": "EXT3"},'
  values+='{"key": "ext2", "value": "EXT2"},'
  values+='{"key": "ntfs", "value": "NTFS"},'
  values+='{"key": "exfat", "value": "exFAT"},'
  values+='{"key": "fat32", "value": "FAT32"}'
  values="[${values}]"

  pick_one 'Select file system type:' "${values}" vertical || return $?
}

# Checks if the given file system type is valid.
# Arguments:
#  type: the type of file system
# Returns:
# 0 if type is valid otherwise 1.
is_valid_fs_type () {
  local type="${1}"

  local types='ext4|ext3|ext2|ntfs|exfat|fat32'

  if not_match "${type}" "^(${types})$"; then
    return 1
  fi

  return 0
}

# An inverse version of is_valid_fs_type.
is_not_valid_fs_type () {
  is_valid_fs_type "${1}" && return 1 || return 0
}

# Shows a menu asking the user to select a
# mounted image path.
# Outputs:
#  A menu of moutned image paths.
pick_image_mount () {
  local mounts=''

  mounts="$(cat /proc/mounts | awk '/^fuseiso/{
    print "{\"key\":\"" $2 "\",\"value\":\"" $2 "\"},"
  }')" || return 1

  # Remove the extra comma after the last element
  mounts="${mounts:+${mounts::-1}}"

  mounts="[${mounts}]"

  local len=0
  len="$(echo "${mounts}" | jq -cer 'length')" || return 1

  if is_true "${len} = 0"; then
    log 'No image mounts have found.'
    return 2
  fi

  pick_one 'Select image mount path:' "${mounts}" vertical || return $?
}

# Shows a menu asking the user to select a shared folder
# mount uri.
# Outputs:
#  A menu of shared folder mount uris.
pick_shared_folder_mount () {
  local uris=''

  uris="$(ls /run/user/${UID}/gvfs | awk '{
    match($0, /domain=(.*),server=(.*),share=(.*),user=(.*)/, a);
    key="smb://"a[1]";"a[4]"@"a[2]"/"a[3]
    print "{\"key\": \""key"\", \"value\":\""key"\"},"
  }')" || return 1

  # Remove the extra comma after the last element
  uris="${uris:+${uris::-1}}"

  uris="[${uris}]"

  local len=0
  len="$(echo "${uris}" | jq -cer 'length')" || return 1

  if is_true "${len} = 0"; then
    log 'No mounted shared folders have found.'
    return 2
  fi

  pick_one 'Select a shared folder mount uri:' "${uris}" vertical || return $?
}

# Asks a user to select an archlinux iso file mirror host.
# Outputs:
#  A menu of mirror hosts.
pick_mirror () {
  local mirrors=''

  mirrors+='{"key": "http://arch.phinau.de/iso/latest", "value": "Germany [phinau.de]"},'
  mirrors+='{"key": "http://mirrors.acm.wpi.edu/archlinux/iso/latest", "value": "USA [acm.wpi.edu]"},'
  mirrors+='{"key": "https://mirror.kamtv.ru/archlinux/iso/latest", "value": "Russia [kamtv.ru]"},'
  mirrors+='{"key": "https://mirrors.bfsu.edu.cn/archlinux/iso/latest", "value": "China [bfsu.edu.cn]"},'
  mirrors+='{"key": "https://mirror.vishmak.in/archlinux/iso/latest", "value": "India [vishmak.in]"},'
  mirrors+='{"key": "http://archlinux.c3sl.ufpr.br/iso/latest", "value": "Brazil [c3sl.ufpr.br]"},'
  mirrors+='{"key": "https://mirror.aarnet.edu.au/pub/archlinux/iso/latest", "value": "Australia [aarnet.edu.au]"}'
  mirrors="[${mirrors}]"

  pick_one 'Select a mirror:' "${mirrors}" vertical || return $?
}

# Downloads the latest iso file from the given mirror host.
# Arguments:
#  mirror:        the uri of the mirror server
#  file_name:     the name of the iso file to download
#  output_folder: the directory to download the iso file
download_iso_file () {
  local mirror="${1}"
  local file_name="${2}"
  local output_folder="${3}"

  local files=(
    "${mirror}/${file_name}"
    "${mirror}/b2sums.txt"
    "${mirror}/${file_name}.sig"
  )

  # Clean up iso, signature and checksum files
  rm -f "${output_folder}/${file_name}"
  rm -f "${output_folder}/b2sums.txt"
  rm -f "${output_folder}/${file_name}.sig"

  download "${output_fodler}" "${files[@]}" || return 1
}

# Verifies the integrity of the archlinux iso file with
# the given name.
# Arguments:
#  folder:    the directory of the iso file
#  file_name: the name of the iso file
verify_iso_file () {
  local folder="${1}"
  local file_name="${2}"

  sq --force wkd get pierre@archlinux.org -o "${folder}/release-key.pgp" || return 1

  cd ${folder} &&
   b2sum --ignore-missing -c b2sums.txt &&
   sq verify --signer-file release-key.pgp \
    --detached "${file_name}.sig" "${file_name}" 2>&1 | awk NF || return 1
}

