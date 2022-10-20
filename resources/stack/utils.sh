#!/usr/bin/env bash

abort () {
  local MESSAGE=${1:-"Something went wrong"}
  local CODE=${2:-1}

  echo "$MESSAGE"
  exit $CODE
}

require () {
  local PACKAGES=("${@}")

  for PKG in "${PACKAGES[@]}"; do
    pacman -Qi "$PKG" > /dev/null || abort "Missing $PKG package"
  done
}

contains () {
  local ITEM=$1 && shift
  local ARR=("${@}")
  local LEN=${#ARR[@]}

  local INDEX=0
  for ((INDEX = 0; INDEX < $LEN; INDEX++)); do
    if [ "$ITEM" = "${ARR[$INDEX]}" ]; then
      return 0
    fi
  done

  return 1
}

askme () {
  local ARGS_LEN=$#
  local PROMPT=$1 && shift

  if [ $ARGS_LEN -gt 2 ]; then
    local OPTIONS=("${@}")

    read -rep "$PROMPT [${OPTIONS[*]}] " REPLY

    while ! contains "$REPLY" "${OPTIONS[@]}"; do
      [[ "$REPLY" =~ ^(quit|q)$ ]] && break

      read -rep " Please enter a valid value: " REPLY
    done
  elif [ $ARGS_LEN -eq 2 ]; then
    local RE=$1 && shift

    read -rep "$PROMPT " REPLY

    while [[ ! "$REPLY" =~ $RE ]]; do
      [[ "$REPLY" =~ ^(quit|q)$ ]] && break

      read -rep " Please enter a valid value: " REPLY
    done
  else
    read -rep "$PROMPT " REPLY
  fi

  if [[ "$REPLY" =~ ^(quit|q)$ ]]; then
    exit 0
  fi
}
