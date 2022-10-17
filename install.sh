#!/usr/bin/env bash

set -a
HOME="$(cd $(dirname "$(test -L "$0" && readlink "$0" || echo "$0")") && pwd)"
OPTIONS="$HOME/.options"
LOG="$HOME/all.log"
set +a

run () {
  bash "$HOME/scripts/${1}.sh" > >(tee -a "$LOG") 2>&1
}

install () {
  local ME="root"
  local SCRIPT_FILE="/${ME}/stack/scripts/${1}.sh"

  if [[ "$1" =~ ^(desktop|apps)$ ]]; then
    source "$OPTIONS" || exit 1

    ME="$USERNAME"
    SCRIPT_FILE="/home/${ME}/stack/scripts/${1}.sh"
  fi

  arch-chroot /mnt runuser -u "$ME" -- "$SCRIPT_FILE" > >(tee -a "$LOG") 2>&1
}

abort () {
  echo -e "\nError: something fatal went wrong"
  echo "Process exiting with code 1..."
  exit 1
}

clear

cat << EOF
░░░█▀▀░▀█▀░█▀█░█▀▀░█░█░░░
░░░▀▀█░░█░░█▀█░█░░░█▀▄░░░
░░░▀▀▀░░▀░░▀░▀░▀▀▀░▀░▀░░░
EOF

echo -e "\nWelcome to Stack v1.0.0"
echo -e "Have your development environment on archlinux\n"

if [[ ! -e /etc/arch-release ]]; then
  echo "Error: this is not an archlinux media"
  echo "Process exiting with code 1..."
  exit 1
fi

echo "Let's start by configuring your system"
read -rep "Do you want to proceed? [Y/n] " REPLY
REPLY="${REPLY:-"yes"}"
REPLY="${REPLY,,}"

if [[ ! "$REPLY" =~ ^(y|yes)$ ]]; then
  echo "Exiting stack installation..."
  exit 0
fi

echo

run "askme" &&
  run "diskpart" &&
  run "bootstrap" &&
  install "system" &&
  install "desktop" &&
  install "apps" &&
  run "reboot" || abort
