#!/usr/bin/env bash

shopt -s nocasematch

ARGS=("$@")
CMD="$1"

case "$CMD" in
  "put")
    trash-put "${ARGS[@]:1}";;
  "empty")
    trash-empty;;
  "list")
    trash-list;;
  "restore")
    trash-restore;;
  "rm")
    echo -e "Selected file(s) will be gone forever:"
    read -p "Do you want to proceed? [y/N] " REPLY
    REPLY=${REPLY:-"n"}

    if [[ $REPLY =~ ^(yes|y)$ ]]; then
      trash-rm "${ARGS[@]:1}"
    fi;;
  *)
    trash-put "${ARGS[@]}";;
esac
