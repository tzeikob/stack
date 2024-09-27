#!/bin/bash

source src/commons/input.sh
source src/commons/logger.sh
source src/commons/text.sh
source src/commons/math.sh
source src/commons/validators.sh

# Returns the remote services having the given status.
# If status is not given all remotes will be returned.
# Arguments:
#  status: mounted or unmounted
# Outputs:
#  A json array of remote objects.
find_remotes () {
  local status="${1}"

  local remotes=''
  remotes="$(rclone listremotes --long 2> /dev/null)" || return 1

  if is_empty "${remotes}"; then
    echo '[]'
    return 0
  fi

  local mounts=''
  mounts="$(< /proc/mounts)"

  local results=''
  local remote=''

  while read -r remote; do
    if is_empty "${remote}"; then
      continue
    fi

    local name=''
    name="$(echo "${remote}" | cut -d ':' -f 1)"

    local service=''
    service="$(echo "${remote}" | cut -d ':' -f 2 | trim)"

    # Check if the remote name exists in the mounts
    local mount=''
    mount="$(grep "^${name}:.* fuse.rclone" <<< "${mounts}")"

    local is_mounted='false'
    local mount_point=''

    if is_not_empty "${mount}"; then
      is_mounted='true'
      mount_point="$(echo "${mount}" | awk '{print $2}')"
    fi

    remote=''
    remote+="\"name\": \"${name}\","
    remote+="\"service\": \"${service}\","
    remote+="\"is_mounted\": ${is_mounted}"

    if is_true "${is_mounted}"; then
      remote+=",\"mount_point\": \"${mount_point}\""
    fi

    remote="{${remote}}"

    if equals "${status}" 'mounted'; then
      is_true "${is_mounted}" && results+="${remote},"
    elif equals "${status}" 'unmounted'; then
      is_false "${is_mounted}" && results+="${remote},"
    else
      results+="${remote},"
    fi
  done; <<< "${remotes}"
  
  # Remove extra comma after the last array element
  results="${results:+${results::-1}}"

  echo "[${results}]"
}

# Returns the remote with the given name.
# Arguments:
#  name: the name of a remote
# Outputs:
#  A json object of remote.
find_remote () {
  local name="${1}"

  local query=".[] | select(.name == \"${name}\")"

  find_remotes | jq -cer "${query}" || return 1
}

# Checks if the service with the given name exists.
# Arguments:
#  name: the name of a service
# Returns:
#  0 if exists otherwise 1
remote_exists () {
  local name="${1}"

  local query=".[] | select(.name == \"${name}\")"

  find_remotes | jq -cer "${query}" &> /dev/null || return 1
}

# An inverse version of remote_exists.
remote_not_exists () {
  remote_exists "${1}" && return 1 || return 0
}

# Checks if the remote with the given name is mounted
# by greping the name in the /proc/mounts file.
# Arguments:
#  name: the name of a service
# Returns:
#  0 if is mounted otherwise 1
is_remote_mounted () {
  local name="${1}"

  grep -Eq "^${name}:.* fuse.rclone" /proc/mounts
}

# An inverse version of is_remote_mounted.
is_remote_not_mounted () {
  is_remote_mounted "${1}" && return 1 || return 0
}

# Shows a menu asking the user to select one remote.
# Arguments:
#  status: mounted or unmounted
# Outputs:
#  A menu of remote names.
pick_remote () {
  local status="${1}"

  local option='{key: .name, value: "\(.name) [\(.service | dft("..."))]"}'

  local query="[.[] | ${option}]"

  local remotes=''
  remotes="$(find_remotes "${status}" | jq -cer "${query}")" || return 1

  local len=0
  len="$(echo "${remotes}" | jq -cer 'length')" || return 1

  if is_true "${len} = 0"; then
    log "No ${status:-\b} remotes have found."
    return 2
  fi

  pick_one "Select remote name:" "${remotes}" "vertical" || return $?
}

