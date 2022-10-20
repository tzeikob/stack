#!/usr/bin/env bash

source ~/.config/stack/utils.sh

require "trash-cli"

trash-list

askme "Which trash operation to apply?" "restore" "remove" "empty"

if [ "$REPLY" = "restore" ]; then
  trash-restore
elif [ "$REPLY" = "remove" ]; then
  askme "Enter the file(s) to remove:" "/.*"

  if [[ ! -z $REPLY ]]; then
    askme "File(s) will be gone forever, proceed?" "yes" "no"

    if [ "$REPLY" = "yes" ]; then
      trash-rm $REPLY
    fi
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
