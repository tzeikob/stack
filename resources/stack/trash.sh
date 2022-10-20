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

trash-list

askme "Which trash operation to apply?" "restore" "remove" "empty"

if [ "$REPLY" = "restore" ]; then
  BEFORE=$(list_files)

  trash-restore

  AFTER=$(list_files)
  RESTORED=$(not_present "$BEFORE" "$AFTER")

  if [ ! -z "$RESTORED" ]; then
    echo "The following files are restored:"
    echo "$RESTORED" | awk '{print " "$1}'
  fi
elif [ "$REPLY" = "remove" ]; then
  askme "Enter a path or pattern to match files for remove:" ".+"
  FILE_PAT="$REPLY"

  askme "ANY MATCHED FILE will be gone, proceed?" "yes" "no"

  if [ "$REPLY" = "yes" ]; then
    BEFORE=$(list_files)

    trash-rm "$FILE_PAT"

    AFTER=$(list_files)
    GONE=$(not_present "$BEFORE" "$AFTER")

    if [ ! -z "$GONE" ]; then
      echo "The following files are removed:"
      echo "$GONE" | awk '{print " "$1}'
    else
      echo "No matched files found, none is removed."
    fi
  fi
elif [ "$REPLY" = "empty" ]; then
  FILES=$(trash-list)

  if [[ ! -z "$FILES" ]]; then
    askme "ALL FILES in trash will be gone, proceed?" "yes" "no"

    if [ "$REPLY" = "yes" ]; then
      BEFORE=$(list_files)

      trash-empty -f

      AFTER=$(list_files)
      GONE=$(not_present "$BEFORE" "$AFTER")

      echo "The following files are removed:"
      echo "$GONE" | awk '{print " "$1}'
      echo "Trash is now empty."
    fi
  else
    echo "Trash is already empty, no files found."
  fi
fi
