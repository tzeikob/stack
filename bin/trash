#!/usr/bin/env bash

shopt -s nocasematch

args=("$@")
cmd="$1"

case "$cmd" in
  "put")
    trash-put "${args[@]:1}";;
  "empty")
    trash-empty;;
  "list")
    trash-list;;
  "restore")
    trash-restore;;
  "rm")
    echo -e "Selected file(s) will be gone forever:"
    read -p "Do you want to proceed? [y/N] " reply
    reply=${reply:-"n"}

    if [[ $reply =~ ^(yes|y)$ ]]; then
      trash-rm "${args[@]:1}"
    fi;;
  *)
    trash-put "${args[@]}";;
esac
