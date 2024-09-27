#!/bin/bash

source src/commons/process.sh
source src/commons/input.sh
source src/commons/error.sh
source src/commons/logger.sh
source src/commons/math.sh
source src/commons/validators.sh
source src/tools/cloud/helpers.sh

# Shows the list of remotes matching the given service.
# Arguments:
#  service: a service name (drive, dropbox e.g.)
# Outputs:
#  A list of remotes.
list_remotes () {
  local service="${1}"

  local query=''
  query="[.[] | select(.service | test(\"${service}\"; \"i\"))]"

  local remotes=''
  remotes="$(find_remotes | jq -cer "${query}")" || return 1

  local len=0
  len="$(echo "${remotes}" | jq -cer 'length')" || return 1
  
  if is_true "${len} = 0"; then
    log "No ${service:-\b} remotes found."
    return 0
  fi

  local query=''
  query+='\(.name        | lbln("Name"))'
  query+='\(.mount_point | olbln("Mount"))'
  query+='\(.service     | lbl("Service"))'
  query="[.[] | \"${query}\"] | join(\"\n\n\")"

  echo "${remotes}" | jq -cer --arg SPC 10 "${query}" || return 1
}

# Creates a new google drive remote with the given name.
# Arguments:
#  name:   the name of the remote
#  client: the google client id
#  secret: the client secret
#  folder: the root folder id
sync_drive () {
  local name="${1}"
  local client="${2}"
  local secret="${3}"
  local folder="${4}"

  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Missing the remote name.' && return 2

    ask 'Enter a remote name:' || return $?
    is_empty "${REPLY}" && log 'Remote name is required.' && return 2
    name="${REPLY}"
  fi
  
  if remote_exists "${name}"; then
    log "Remote ${name} already exists."
    return 2
  fi
  
  if is_not_given "${client}"; then
    on_script_mode &&
      log 'Missing the client id.' && return 2

    ask 'Enter the client id:' || return $?
    is_empty "${REPLY}" && log 'Client id is required.' && return 2
    client="${REPLY}"
  fi
  
  if is_not_given "${secret}"; then
    on_script_mode &&
      log 'Missing the client secret.' && return 2

    ask 'Enter the client secret:' || return $?
    is_empty "${REPLY}" && log 'Client secret is required.' && return 2
    secret="${REPLY}"
  fi
  
  if is_not_given "${folder}" && on_user_mode; then
    ask 'Enter the root folder id [none]:' || return $?
    folder="${REPLY}"
  fi

  log 'Go to browser and accept access permssions...'

  rclone config create "${name}" drive scope=drive client_id="${client}" \
    client_secret="${secret}" root_folder_id="${folder}" &> /dev/null

  if has_failed; then
    log 'Failed to sync drive remote.'
    rclone config delete "${name}"
    return 2
  fi

  log "Drive remote ${name} synced."
}

# Creates a new dropbox remote with the given name.
# Arguments:
#  name:   the name of the remote
#  app:    the dropbox application key
#  secret: the application secret
sync_dropbox () {
  local name="${1}"
  local app="${2}"
  local secret="${3}"

  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Missing the remote name.' && return 2

    ask 'Enter the remote name:' || return $?
    is_empty "${REPLY}" && log 'Remote name is required.' && return 2
    name="${REPLY}"
  fi
  
  if remote_exists "${name}"; then
    log "Remote ${name} already exists."
    return 2
  fi

  if is_not_given "${app}"; then
    on_script_mode &&
      log 'Missing the application key.' && return 2

    ask 'Enter the application key:' || return $?
    is_empty "${REPLY}" && log 'Application key is required.' && return 2
    app="${REPLY}"
  fi

  if is_not_given "${secret}"; then
    on_script_mode &&
      log 'Missing the application secret.' && return 2

    ask 'Enter the application secret:' || return $?
    is_empty "${REPLY}" && log 'Application secret is required.' && return 2
    secret="${REPLY}"
  fi

  log 'Go to browser and accept access permssions...'

  rclone config create "${name}" dropbox \
    client_id="${app}" client_secret="${secret}" &> /dev/null

  if has_failed; then
    log 'Failed to sync dropbox remote.'
    rclone config delete "${name}"
    return 2
  fi

  log "Dropbox remote ${name} synced."
}

# Deletes the remote with the given name.
# Arguments:
#  name: the name of a remote
delete_remote () {
  local name="${1}"
  
  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Missing the remote name.' && return 2

    pick_remote unmounted || return $?
    is_empty "${REPLY}" && log 'Remote name is required.' && return 2
    name="${REPLY}"
  fi
  
  if remote_not_exists "${name}"; then
    log "Remote ${name} not found."
    return 2
  elif is_remote_mounted "${name}"; then
    log 'Cannot delete a mounted remote.'
    return 2
  fi

  if on_user_mode; then
    log "Remote ${name} will be deleted!"
    confirm 'Do you realy want to proceed?' || return $?
    is_empty "${REPLY}" && log 'Confirmation is required.' && return 2
    
    if is_not_yes "${REPLY}"; then
      log 'Deletion operation is canceled.'
      return 2
    fi
  fi

  rclone config delete "${name}"

  if has_failed; then
    log 'Failed to delete remote.'
    return 2
  fi
  
  log "Remote ${name} has been deleted."
}

# Mounts the remote with the given name to the disk.
# Arguments:
#  name: the name of the remote
mount_remote () {
  local name="${1}"

  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Missing the remote name.' && return 2

    pick_remote unmounted || return $?
    is_empty "${REPLY}" && log 'Remote name is required.' && return 2
    name="${REPLY}"
  fi
  
  if remote_not_exists "${name}"; then
    log "Remote ${name} not found."
    return 2
  elif is_remote_mounted "${name}"; then
    log "Remote ${name} is already mounted."
    return 2
  fi

  log "Mounting remote ${name}..."

  local mount_folder="${HOME}/mounts/cloud/${name}"

  mkdir -p "${mount_folder}" '/tmp/rclone' &&
  rclone mount "${name}:" "${mount_folder}" \
    --umask=002 --gid=$(id -g) --uid=$(id -u) --timeout=1h \
    --poll-interval=15s --dir-cache-time=1000h --vfs-cache-mode=full \
    --vfs-cache-max-size=150G --vfs-cache-max-age=12h \
    --log-level=INFO --log-file="/tmp/rclone/${name}.log" --daemon

  if has_failed; then
    # Remove the dangling root mount folder if it is empty
    find "${mount_folder}" -maxdepth 0 -empty -exec rm -rf {} \;

    log 'Failed to mount remote.'
    return 2
  fi

  log "Remote ${name} mounted to ${mount_folder}."
}

# Unmounts the remote with the given name from the disk.
# Arguments:
#  name: the name of the remote
unmount_remote () {
  local name="${1}"

  if is_not_given "${name}"; then
    on_script_mode &&
      log 'Missing the remote name.' && return 2
    
    pick_remote mounted || return $?
    is_empty "${REPLY}" && log 'Remote name is required.' && return 2
    name="${REPLY}"
  fi
  
  if remote_not_exists "${name}"; then
    log "Remote ${name} not found."
    return 2
  elif is_remote_not_mounted "${name}"; then
    log "Remote ${name} is not mounted."
    return 2
  fi

  log "Unmounting remote ${name}..."

  local remote=''
  remote="$(find_remote "${name}")" || return 1

  local mount_point=''
  mount_point="$(echo "${remote}" | jq -cer '.mount_point')" || return 1

  fusermount -uz "${mount_point}"

  if has_failed; then
    log 'Failed to unmount remote.'
    return 2
  fi

  # Remove root folder of the mount only if it is empty
  find "${mount_point}" -maxdepth 0 -empty -exec rm -rf {} \;

  log "Remote ${name} has been unmounted."
}

# Mounts all the synced remotes.
mount_all () {
  local remotes=''
  remotes="$(find_remotes)" || return 1

  local len=0
  len="$(echo "${remotes}" | jq -cer 'length')" || return 1

  if is_true "${len} = 0"; then
    log 'No remotes have been found.'
    return 2
  fi

  # Iterate over remote names and mount remotes one by one
  remotes="$(echo "${remotes}" | jq -cr '.[] | .name')" || return 1

  local failed=0
  local remote=''

  while read -r remote; do
    mount_remote "${remote}"

    if has_failed; then
      log "Failed to mount remote ${remote}."
      failed="$(calc "${failed} + 1")" || return 1
      continue
    fi
  
    log "Remote ${remote} has been mounted."
  done <<< "${remotes}"

  if is_true "${failed} > 0"; then
    log "${failed} remotes failed to be mounted."
    return 2
  fi

  log 'All remotes have been mounted.'
}

