#!/bin/bash

set -o pipefail

source /opt/stack/commons/utils.sh
source /opt/stack/commons/logger.sh
source /opt/stack/commons/input.sh
source /opt/stack/commons/json.sh
source /opt/stack/commons/math.sh
source /opt/stack/commons/validators.sh
source /opt/stack/tools/trash/helpers.sh

# Show the list of trashed files filtered by the given
# value. If the filter is an integer number the filter
# selects only the files trashed within the given days,
# if the number is prefixed with + the filter selects
# the files trashed more than the given days ago and if
# the filter is a date YYYY-MM-dd the filter selects
# the files trashed the exact given date.
# Arguments:
#  filter: number of days or a certain date
# Outputs:
#  A list of trashed files.
list_files () {
  local filter="${1}"

  local query=''

  if is_integer "${filter}" '[0,]'; then
    query="[.[]|select((now - .epoch) / 86400 < ${filter})]"
  elif match "${filter}" '^\+' && is_integer "${filter:1}" '[0,]'; then
    query="[.[]|select((now - .epoch) / 86400 > ${filter:1})]"
  elif is_date "${filter}"; then
    filter="$(date -d ${filter} +%s)"
    query="[.[]|select(${filter} - .epoch_date == 0)]"
  elif is_not_given "${filter}"; then
    query='.'
  else
    log 'Invalid filter value.'
    return 2
  fi

  local files=''
  files="$(find_files | jq -cer "${query}")" || return 1

  local len=0
  len="$(get_len "${files}")" || return 1

  if is_true "${len} = 0"; then
    log 'No trashed files have found.'
    return 0
  fi

  query='.[]|"\(.date) \(.time) \(.path)"'

  echo "${files}" | jq -cer "${query}" || return 1
}

# Restores trashed files with the given path.
# Arguments:
#  paths: space separated list of file paths
restore_files () {
  local paths=("$@")

  # Find all trashed files eligible for restoring
  local files=''
  files="$(find_restorable_files)" || return 1

  local len=0
  len="$(get_len "${files}")" || return 1

  if is_true "${len} = 0"; then
    log 'No trashed files found.'
    return 2
  fi

  local file_keys=''

  if is_true "${#paths[@]} = 0"; then
    on_script_mode &&
      log 'No file paths are given.' && return 2

    pick_many 'Select files to restore:' "${files}" vertical || return $?
    is_empty "${REPLY}" && log 'File paths are required.' && return 2
    local picked="${REPLY}"

    # Refuse to overwrite existing files
    picked="$(echo "${picked}" | jq -cer 'join(" ")')" || return 1

    local key=''
    for key in ${picked}; do
      # Match file by trash-restore index key
      local query=".[]|select(.key == \"${key}\")|.value"

      local path=''
      path="$(echo "${files}" | jq -cr "${query}")"

      if file_exists "${path}"; then
        log "Refused to overwrite file ${path}."
        continue
      fi

      file_keys+="${key},"
    done

    # Remove extra comma from the last element
    file_keys="${file_keys:+${file_keys::-1}}"
  else
    local path=''
    for path in "${paths[@]}"; do
      # Match file by file path
      local query=".[]|select(.value == \"${path}\")|.key"

      local key=''
      key="$(echo "${files}" | jq -cer "${query}")"

      if has_failed; then
        log "File ${path} not found in trash."
        continue
      fi

      if file_exists "${path}"; then
        log "Refused to overwrite file ${path}."
        continue
      fi

      file_keys+="${key},"
    done

    # Remove the extra comma delimiter from last element
    file_keys="${file_keys:+${file_keys::-1}}"

    file_keys="[${file_keys}]"

    # Discard possible duplicated files
    file_keys="$(echo "${file_keys}" | jq -cr 'unique|join(",")')"
  fi

  trash-restore / &> /dev/null <<< "${file_keys}"

  if has_failed; then
    log 'Failed to restore files.'
    return 2
  fi

  local post_len=0
  post_len="$(find_files | jq -cer 'length')" || return 1
  len="$(calc "${len} - ${post_len}")" || return 1

  if is_true "${len} = 0"; then
    log 'No files restored.'
    return 2
  fi

  log "${len} file(s) have been restored."
}

# Removes the trashed files, given as a list of paths.
# Arguments:
#  paths: a space separated list of file paths
remove_files () {
  local paths=("$@")

  # Collect all trashed files eligible for removal
  local files=''
  files="$(find_files)" || return 1

  local len=0
  len="$(get_len "${files}")" || return 1

  if is_true "${len} = 0"; then
    log 'No trashed files found.'
    return 2
  fi

  # Convert file list into key-value pairs
  local query='[.[]|{key: .path, value: "\(.date) \(.path)"}]'
  files="$(echo "${files}" | jq -cer "${query}")" || return 1
  
  if is_true "${#paths[@]} = 0"; then
    on_script_mode &&
      log 'No file paths are given.' && return 2

    pick_many 'Select files to remove:' "${files}" vertical || return $?
    is_empty "${REPLY}" && log 'File paths are required.' && return 2
    local selected_paths="${REPLY}"

    readarray -t paths < <(echo "${selected_paths}" | jq -cr '.[]')
  fi

  if on_user_mode; then
    confirm 'File(s) will be gone forever, proceed?' || return $?
    is_empty "${REPLY}" && log 'Confirmation is required.' && return 2
  
    if is_not_yes "${REPLY}"; then
      log 'No trashed files removed.'
      return 2
    fi
  fi

  local path=''
  for path in "${paths[@]}"; do
    local query=".[]|select(.key == \"${path}\")"

    echo "${files}" | jq -cer "${query}" &> /dev/null

    if has_failed; then
      log "File ${path} not found in trash."
      continue
    fi

    trash-rm "${path}"
  done

  local post_len=0
  post_len="$(find_files | jq -cer 'length')" || return 1
  len="$(calc "${len} - ${post_len}")" || return 1

  if is_true "${len} = 0"; then
    log 'No trashed files removed.'
    return 2
  fi
  
  log "${len} trashed file(s) removed."
}

# Empties the trash from files trashed more than
# the given days ago.
# Arguments:
#  days: a positive integer number
empty_files () {
  local days="${1}"
  
  if is_given "${days}" && is_not_integer "${days}" '[0,]'; then
    log 'Invalid days filter.'
    return 2
  fi

  local len=0
  len="$(find_files | jq -cer 'length')" || return 1

  if is_true "${len} = 0"; then
    log 'No trashed files found.'
    return 2
  fi
  
  if on_user_mode; then
    local prompt=''

    if is_not_given "${days}"; then
      prompt='ALL trashed files will be gone, proceed?'
    else
      prompt="Files trashed more than ${days} days ago will be gone, proceed?"
    fi
  
    confirm "${prompt}" || return $?
    is_empty "${REPLY}" && log 'Confirmation is required.' && return 2

    if is_not_yes "${REPLY}"; then
      log 'No trashed files removed.'
      return 2
    fi
  fi

  trash-empty -f "${days:-0}"

  if has_failed; then
    log 'Failed to remove trashed files.'
    return 2
  fi

  local post_len=0
  post_len="$(find_files | jq -cer 'length')" || return 1
  len="$(calc "${len} - ${post_len}")" || return 1

  if is_true "${len} = 0"; then
    log 'No trashed files removed.'
    return 2
  fi

  log "${len} trashed file(s) removed."
}

