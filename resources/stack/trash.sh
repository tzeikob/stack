#!/usr/bin/env bash

source ~/.config/stack/utils.sh

require "trash-cli"

trash-list

askme "Which trash operation to apply?" "restore" "remove" "empty"

if [ "$REPLY" = "restore" ]; then
  trash-restore
elif [ "$REPLY" = "remove" ]; then
  askme "Enter a path or pattern to match files for remove:" ".+"
  FILE_PAT="$REPLY"

  askme "MATCHED FILES will be gone forever, proceed?" "yes" "no"

  if [ "$REPLY" = "yes" ]; then
    trash-rm "$FILE_PAT"
  fi
elif [ "$REPLY" = "empty" ]; then
  FILES=$(trash-list)

  if [[ ! -z "$FILES" ]]; then
    askme "ALL FILES in trash will be gone, proceed?" "yes" "no"

    if [ "$REPLY" = "yes" ]; then
      trash-empty -f
      echo "Trash is now empty, no files found."
    fi
  else
    echo "Trash is already empty, no files to remove."
  fi
fi
