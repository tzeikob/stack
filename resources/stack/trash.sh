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
    askme "File(s) will be gone forever, are you sure?" "yes" "no"

    if [ "$REPLY" = "yes" ]; then
      trash-rm $REPLY
    fi
  fi
elif [ "$REPLY" = "empty" ]; then
  askme "File(s) will be gone forever, are you sure?" "yes" "no"

  if [ "$REPLY" = "yes" ]; then
    trash-empty -f
  fi
fi
