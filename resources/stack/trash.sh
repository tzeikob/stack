#!/usr/bin/env bash

source ~/.config/stack/utils.sh

require "trash-cli"

not_present () {
  local BEFORE=($1)
  local AFTER=($2)

  for EXISTED in "${BEFORE[@]}"; do
    local IS_FOUND="false"

    for REMAINED in "${AFTER[@]}"; do
      if [ "$EXISTED" = "$REMAINED" ]; then
        IS_FOUND="true"
        break
      fi
    done

    if [ "$IS_FOUND" = "false" ]; then
      echo "$EXISTED"
    fi
  done
}

list_files () {
  trash-list | awk '{print $3}'
}

restore_files () {
  local BEFORE=$(list_files)

  trash-restore

  local AFTER=$(list_files)
  local RESTORED=$(not_present "$BEFORE" "$AFTER")

  if [ ! -z "$RESTORED" ]; then
    echo "The following files are restored:"
    echo "$RESTORED" | awk '{print " "$1}'
  fi
}

remove_files () {
  askme "Enter a path or pattern to match files for remove:" ".+"
  local FILE_PAT="$REPLY"

  askme "ANY MATCHED FILE will be gone, proceed?" "yes" "no"

  if [ "$REPLY" = "yes" ]; then
    local BEFORE=$(list_files)

    trash-rm "$FILE_PAT"

    local AFTER=$(list_files)
    local GONE=$(not_present "$BEFORE" "$AFTER")

    if [ ! -z "$GONE" ]; then
      echo "The following files are removed:"
      echo "$GONE" | awk '{print " "$1}'
    else
      echo "No matched files found, none is removed."
    fi
  fi
}

empty_files () {
  local FILES=$(trash-list)

  if [[ ! -z "$FILES" ]]; then
    askme "ALL FILES in trash will be gone, proceed?" "yes" "no"

    if [ "$REPLY" = "yes" ]; then
      local BEFORE=$(list_files)

      trash-empty -f

      local AFTER=$(list_files)
      local GONE=$(not_present "$BEFORE" "$AFTER")

      echo "The following files are removed:"
      echo "$GONE" | awk '{print " "$1}'
      echo "Trash is now empty."
    fi
  else
    echo "Trash is already empty, no files found."
  fi
}

trash_files () {
  local ARGS=("$@")
  local FIRST_ARG=${ARGS[0]}

  if [ "$FIRST_ARG" = "-r" ]; then
    echo "${ARGS[@]:1}" | awk '{print $1}'
    askme "The files will be GONE FOREVER, proceed?" "yes" "no"

    if [ "$REPLY" = "yes" ]; then
      rm -rf "${ARGS[@]:1}"
    fi
  else
    local BEFORE=$(list_files)

    trash-put "${ARGS[@]}"

    local AFTER=$(list_files)
    local TRASHED=$(not_present "$AFTER" "$BEFORE")

    echo "The following files are trashed:"
    echo "$TRASHED" | awk '{print " "$1}'
  fi
}

ARGS=("$@")
ARGS_LEN=${#ARGS[@]}

if [ $ARGS_LEN = 0 ]; then
  trash-list

  askme "Which trash operation to apply?" "restore" "remove" "empty"

  if [ "$REPLY" = "restore" ]; then
    restore_files
  elif [ "$REPLY" = "remove" ]; then
    remove_files
  elif [ "$REPLY" = "empty" ]; then
    empty_files
  fi
else
  trash_files "${ARGS[@]}"
fi
